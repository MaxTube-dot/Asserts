# Реализация Source Generator для анализа DbContext в архитектуре Blazor + API + Data

Ваша задача вполне решаема с помощью Source Generators в .NET 8. Рассмотрю оптимальную архитектуру проекта и способы её реализации.

## Рекомендуемая архитектура проекта

### Структура решения

```
MySolution/
├── MyApp.Blazor/          (зависит от API)
├── MyApp.API/             (зависит от Data, SourceGenerator)
├── MyApp.Data/            (содержит DbContext)
└── MyApp.SourceGenerator/ (анализирует Data, генерирует в API)
```

### Конфигурация проектов

**MyApp.SourceGenerator.csproj:**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <LangVersion>12</LangVersion>
    <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
    <CompilerGeneratedFilesOutputPath>Generated</CompilerGeneratedFilesOutputPath>
    <OutputItemType>Analyzer</OutputItemType>
    <IncludeBuildOutput>false</IncludeBuildOutput>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.CodeAnalysis.Analyzers" Version="3.3.4">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp" Version="4.5.0" PrivateAssets="all" />
  </ItemGroup>

  <!-- Ссылка на Data проект для анализа -->
  <ItemGroup>
    <ProjectReference Include="../MyApp.Data/MyApp.Data.csproj" OutputItemType="Analyzer" />
  </ItemGroup>
</Project>
```

**MyApp.API.csproj:**
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
    <CompilerGeneratedFilesOutputPath>Generated</CompilerGeneratedFilesOutputPath>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="../MyApp.Data/MyApp.Data.csproj" />
    <ProjectReference Include="../MyApp.SourceGenerator/MyApp.SourceGenerator.csproj" 
                      OutputItemType="Analyzer" 
                      ReferenceOutputAssembly="false" />
  </ItemGroup>

  <!-- Исключение сгенерированных файлов из двойной компиляции -->
  <ItemGroup>
    <Compile Remove="$(CompilerGeneratedFilesOutputPath)/**/*.cs" />
  </ItemGroup>
</Project>
```

**MyApp.Data.csproj:**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
  </ItemGroup>
</Project>
```

## Реализация Source Generator

### Пример DbContext в Data проекте

```csharp
// MyApp.Data/ApplicationDbContext.cs
public class ApplicationDbContext : DbContext
{
    public DbSet<User> Users { get; set; }
    public DbSet<Product> Products { get; set; }
    public DbSet<Order> Orders { get; set; }

    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) 
        : base(options) { }
}

public class User
{
    public int Id { get; set; }
    public string Name { get; set; }
    public string Email { get; set; }
}
```

### Incremental Source Generator

```csharp
// MyApp.SourceGenerator/DbContextAnalyzer.cs
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Text;
using System.Text;

[Generator]
public class DbContextAnalyzer : IIncrementalGenerator
{
    public void Initialize(IncrementalGeneratorInitializationContext context)
    {
        // Поиск классов DbContext
        var dbContextClasses = context.SyntaxProvider
            .CreateSyntaxProvider(
                predicate: static (node, _) => IsDbContextClass(node),
                transform: static (ctx, _) => GetDbContextInfo(ctx))
            .Where(static m => m is not null);

        // Генерация кода для каждого найденного DbContext
        context.RegisterSourceOutput(dbContextClasses, 
            static (spc, dbContextInfo) => GenerateRepositories(spc, dbContextInfo!));
    }

    private static bool IsDbContextClass(SyntaxNode node)
    {
        return node is ClassDeclarationSyntax classDecl && 
               classDecl.BaseList?.Types.Any(baseType => 
                   baseType.Type.ToString().Contains("DbContext")) == true;
    }

    private static DbContextInfo? GetDbContextInfo(GeneratorSyntaxContext context)
    {
        var classDecl = (ClassDeclarationSyntax)context.Node;
        var symbol = context.SemanticModel.GetDeclaredSymbol(classDecl) as INamedTypeSymbol;
        
        if (symbol == null) return null;

        // Проверяем, что это действительно DbContext
        var isDbContext = symbol.BaseType?.Name == "DbContext" || 
                         IsInheritedFromDbContext(symbol.BaseType);

        if (!isDbContext) return null;

        var dbSets = new List<DbSetInfo>();
        
        // Анализируем DbSet свойства
        foreach (var member in symbol.GetMembers().OfType<IPropertySymbol>())
        {
            if (IsDbSetProperty(member))
            {
                var entityType = GetDbSetEntityType(member);
                if (entityType != null)
                {
                    dbSets.Add(new DbSetInfo(member.Name, entityType));
                }
            }
        }

        return new DbContextInfo(symbol.Name, symbol.ContainingNamespace.ToDisplayString(), dbSets);
    }

    private static bool IsInheritedFromDbContext(INamedTypeSymbol? baseType)
    {
        while (baseType != null)
        {
            if (baseType.Name == "DbContext") return true;
            baseType = baseType.BaseType;
        }
        return false;
    }

    private static bool IsDbSetProperty(IPropertySymbol property)
    {
        return property.Type is INamedTypeSymbol namedType && 
               namedType.Name == "DbSet" && 
               namedType.TypeArguments.Length == 1;
    }

    private static string? GetDbSetEntityType(IPropertySymbol property)
    {
        if (property.Type is INamedTypeSymbol namedType && 
            namedType.TypeArguments.Length == 1)
        {
            return namedType.TypeArguments[0].Name;
        }
        return null;
    }

    private static void GenerateRepositories(SourceProductionContext context, DbContextInfo dbContextInfo)
    {
        var sb = new StringBuilder();
        
        // Генерируем репозитории для каждого DbSet
        foreach (var dbSet in dbContextInfo.DbSets)
        {
            sb.Clear();
            GenerateRepository(sb, dbContextInfo, dbSet);
            
            context.AddSource($"{dbSet.EntityName}Repository.g.cs", 
                SourceText.From(sb.ToString(), Encoding.UTF8));
        }

        // Генерируем Unit of Work
        sb.Clear();
        GenerateUnitOfWork(sb, dbContextInfo);
        context.AddSource("UnitOfWork.g.cs", 
            SourceText.From(sb.ToString(), Encoding.UTF8));
    }

    private static void GenerateRepository(StringBuilder sb, DbContextInfo dbContextInfo, DbSetInfo dbSet)
    {
        sb.AppendLine("// <auto-generated />");
        sb.AppendLine("using Microsoft.EntityFrameworkCore;");
        sb.AppendLine($"using {dbContextInfo.Namespace};");
        sb.AppendLine();
        sb.AppendLine($"namespace {dbContextInfo.Namespace}.Repositories");
        sb.AppendLine("{");
        sb.AppendLine($"    public interface I{dbSet.EntityName}Repository");
        sb.AppendLine("    {");
        sb.AppendLine($"        Task<{dbSet.EntityName}?> GetByIdAsync(int id);");
        sb.AppendLine($"        Task<List<{dbSet.EntityName}>> GetAllAsync();");
        sb.AppendLine($"        Task<{dbSet.EntityName}> AddAsync({dbSet.EntityName} entity);");
        sb.AppendLine($"        Task UpdateAsync({dbSet.EntityName} entity);");
        sb.AppendLine($"        Task DeleteAsync(int id);");
        sb.AppendLine("    }");
        sb.AppendLine();
        sb.AppendLine($"    public class {dbSet.EntityName}Repository : I{dbSet.EntityName}Repository");
        sb.AppendLine("    {");
        sb.AppendLine($"        private readonly {dbContextInfo.ClassName} _context;");
        sb.AppendLine();
        sb.AppendLine($"        public {dbSet.EntityName}Repository({dbContextInfo.ClassName} context)");
        sb.AppendLine("        {");
        sb.AppendLine("            _context = context;");
        sb.AppendLine("        }");
        sb.AppendLine();
        sb.AppendLine($"        public async Task<{dbSet.EntityName}?> GetByIdAsync(int id)");
        sb.AppendLine("        {");
        sb.AppendLine($"            return await _context.{dbSet.PropertyName}.FindAsync(id);");
        sb.AppendLine("        }");
        sb.AppendLine();
        sb.AppendLine($"        public async Task<List<{dbSet.EntityName}>> GetAllAsync()");
        sb.AppendLine("        {");
        sb.AppendLine($"            return await _context.{dbSet.PropertyName}.ToListAsync();");
        sb.AppendLine("        }");
        sb.AppendLine();
        sb.AppendLine($"        public async Task<{dbSet.EntityName}> AddAsync({dbSet.EntityName} entity)");
        sb.AppendLine("        {");
        sb.AppendLine($"            _context.{dbSet.PropertyName}.Add(entity);");
        sb.AppendLine("            await _context.SaveChangesAsync();");
        sb.AppendLine("            return entity;");
        sb.AppendLine("        }");
        sb.AppendLine();
        sb.AppendLine($"        public async Task UpdateAsync({dbSet.EntityName} entity)");
        sb.AppendLine("        {");
        sb.AppendLine($"            _context.{dbSet.PropertyName}.Update(entity);");
        sb.AppendLine("            await _context.SaveChangesAsync();");
        sb.AppendLine("        }");
        sb.AppendLine();
        sb.AppendLine($"        public async Task DeleteAsync(int id)");
        sb.AppendLine("        {");
        sb.AppendLine($"            var entity = await GetByIdAsync(id);");
        sb.AppendLine("            if (entity != null)");
        sb.AppendLine("            {");
        sb.AppendLine($"                _context.{dbSet.PropertyName}.Remove(entity);");
        sb.AppendLine("                await _context.SaveChangesAsync();");
        sb.AppendLine("            }");
        sb.AppendLine("        }");
        sb.AppendLine("    }");
        sb.AppendLine("}");
    }

    private static void GenerateUnitOfWork(StringBuilder sb, DbContextInfo dbContextInfo)
    {
        sb.AppendLine("// <auto-generated />");
        sb.AppendLine($"using {dbContextInfo.Namespace};");
        sb.AppendLine($"using {dbContextInfo.Namespace}.Repositories;");
        sb.AppendLine();
        sb.AppendLine($"namespace {dbContextInfo.Namespace}.Services");
        sb.AppendLine("{");
        sb.AppendLine("    public interface IUnitOfWork");
        sb.AppendLine("    {");
        
        foreach (var dbSet in dbContextInfo.DbSets)
        {
            sb.AppendLine($"        I{dbSet.EntityName}Repository {dbSet.EntityName}Repository {{ get; }}");
        }
        
        sb.AppendLine("        Task<int> SaveChangesAsync();");
        sb.AppendLine("    }");
        sb.AppendLine();
        sb.AppendLine("    public class UnitOfWork : IUnitOfWork");
        sb.AppendLine("    {");
        sb.AppendLine($"        private readonly {dbContextInfo.ClassName} _context;");
        sb.AppendLine();
        
        foreach (var dbSet in dbContextInfo.DbSets)
        {
            sb.AppendLine($"        public I{dbSet.EntityName}Repository {dbSet.EntityName}Repository {{ get; }}");
        }
        
        sb.AppendLine();
        sb.AppendLine($"        public UnitOfWork({dbContextInfo.ClassName} context)");
        sb.AppendLine("        {");
        sb.AppendLine("            _context = context;");
        
        foreach (var dbSet in dbContextInfo.DbSets)
        {
            sb.AppendLine($"            {dbSet.EntityName}Repository = new {dbSet.EntityName}Repository(_context);");
        }
        
        sb.AppendLine("        }");
        sb.AppendLine();
        sb.AppendLine("        public async Task<int> SaveChangesAsync()");
        sb.AppendLine("        {");
        sb.AppendLine("            return await _context.SaveChangesAsync();");
        sb.AppendLine("        }");
        sb.AppendLine("    }");
        sb.AppendLine("}");
    }
}

// Вспомогательные классы
public record DbContextInfo(string ClassName, string Namespace, List<DbSetInfo> DbSets);
public record DbSetInfo(string PropertyName, string EntityName);
```

## Регистрация сервисов в API проекте

```csharp
// MyApp.API/Program.cs
using MyApp.Data;
using MyApp.Data.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Регистрация DbContext
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Регистрация сгенерированных репозиториев
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();

var app = builder.Build();
app.Run();
```

## Использование в API контроллерах

```csharp
// MyApp.API/Controllers/UsersController.cs
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;

    public UsersController(IUnitOfWork unitOfWork)
    {
        _unitOfWork = unitOfWork;
    }

    [HttpGet]
    public async Task<ActionResult<List<User>>> GetUsers()
    {
        var users = await _unitOfWork.UserRepository.GetAllAsync();
        return Ok(users);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<User>> GetUser(int id)
    {
        var user = await _unitOfWork.UserRepository.GetByIdAsync(id);
        return user == null ? NotFound() : Ok(user);
    }
}
```

## Ключевые моменты реализации

### 1. Зависимости между проектами
- Source Generator должен ссылаться на Data проект с `OutputItemType="Analyzer"`[1]
- API проект ссылается на Data и Source Generator проекты[2]
- Blazor проект ссылается только на API[2]

### 2. Конфигурация Source Generator
- Обязательно использовать `netstandard2.0` для Source Generator проекта[3][2]
- Настроить `EmitCompilerGeneratedFiles=true` для отладки[4]
- Исключить сгенерированные файлы из компиляции в целевом проекте[4]

### 3. Анализ кросс-проектных зависимостей
Source Generator может анализировать типы из других проектов через `context.Compilation.References` и получать доступ к символам через `context.Compilation.GetAssemblyOrModuleSymbol()`.[5]

### 4. Отладка и тестирование
Используйте `Debugger.Launch()` в Source Generator для отладки и проверьте узел "Analyzers" в Solution Explorer для контроля работы генератора.[6]

Такая архитектура обеспечивает чистое разделение слоёв, позволяет Source Generator анализировать DbContext из Data проекта и генерировать нужный код в API проекте, что полностью соответствует вашим требованиям для .NET 8.

Источники
[1] Reference local projects in Source Generator #47517 https://github.com/dotnet/roslyn/discussions/47517
[2] Dotnet Source Generators in 2024 Part 1: Getting Started https://posts.specterops.io/dotnet-source-generators-in-2024-part-1-getting-started-76d619b633f5
[3] Impossible to implement Source Generators for projects ... https://github.com/dotnet/roslyn/issues/70922
[4] How to set up the project properties for Source Generators https://www.ankursheel.com/blog/setup-project-properties-source-generators
[5] c# - .NET 6 source generator - create classes within ... https://stackoverflow.com/questions/74094151/net-6-source-generator-create-classes-within-another-project
[6] C# Source Generator not including results from Project ... https://stackoverflow.com/questions/69764185/c-sharp-source-generator-not-including-results-from-project-reference
[7] Purpose of EF 6.x DbContext Generator option when ... https://stackoverflow.com/questions/22791170/purpose-of-ef-6-x-dbcontext-generator-option-when-adding-a-new-data-item-in-visu
[8] Issue #108164 · dotnet/runtime https://github.com/dotnet/runtime/issues/107926
[9] Deploying a C# source generator project that includes ... https://stackoverflow.com/questions/71367501/deploying-a-c-sharp-source-generator-project-that-includes-references-to-other-p
[10] Source Generator for EFCore for DB First users. #27553 https://github.com/dotnet/efcore/issues/27553
[11] C# Source Generator Build Issues between Projects https://www.reddit.com/r/csharp/comments/1e7xt6j/c_source_generator_build_issues_between_projects/
[12] Compile-time configuration source generation - .NET https://learn.microsoft.com/en-us/dotnet/core/extensions/configuration-generator
[13] Dotnet Source Generators in 2024 Part 1: Getting Started https://specterops.io/blog/2024/10/01/dotnet-source-generators-in-2024-part-1-getting-started/
[14] The .NET Compiler Platform SDK (Roslyn APIs) - C# https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/
[15] Deep dive into Source Generators https://thecodeman.net/posts/source-generators-deep-dive
[16] Using C# Source Generators to Generate Data Transfer ... https://amanagrawal.blog/2021/07/27/using-c-sharp-source-generators-to-generate-dtos/
[17] Adapt Code Generation Based on Project Dependencies https://www.thinktecture.com/net/roslyn-source-generators-code-according-to-dependencies/
[18] Introducing C# Source Generators - .NET Blog https://devblogs.microsoft.com/dotnet/introducing-c-source-generators/
[19] amis92/csharp-source-generators: A list of C# ... https://github.com/amis92/csharp-source-generators
[20] Incremental Roslyn Source Generators In .NET 6 https://www.thinktecture.com/net/roslyn-source-generators-introduction/
[21] Can incremental generators be used with .NET 8+? : r/csharp https://www.reddit.com/r/csharp/comments/1g8y03p/can_incremental_generators_be_used_with_net_8/
[22] .NET Handbook | Best Practices / Source Generators https://infinum.com/handbook/dotnet/best-practices/source-generators
[23] How to use source generation in System.Text.Json - .NET https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/source-generation
[24] Source Generators and Metaprogramming in .NET - DevOps.dev https://blog.devops.dev/source-generators-and-metaprogramming-in-net-5c92fd513115
[25] Generated interface implementations for Entity Framework ... https://github.com/jscarle/GeneratedEntityFramework
[26] Mastering Incremental Source Generators in C# Complete ... https://blog.elmah.io/mastering-incremental-source-generators-in-csharp-a-complete-guide-with-example/
[27] Unable to create a DbContext' Error when Using EF Core ... https://learn.microsoft.com/en-us/answers/questions/1689899/unable-to-create-a-dbcontext-error-when-using-ef-c
[28] c# - Access multiple projects from IIncrementalGenerator https://stackoverflow.com/questions/72729428/access-multiple-projects-from-iincrementalgenerator
[29] Incremental Roslyn Source Generators: Using 3rd-Party ... https://www.thinktecture.com/net/roslyn-source-generators-using-3rd-party-libraries/
[30] Debug Source Generators in JetBrains Rider https://blog.jetbrains.com/dotnet/2023/07/13/debug-source-generators-in-jetbrains-rider/
[31] Source Generators in C# https://code-maze.com/csharp-source-generators/
[32] Source generated ValueConverter with EF Core https://stackoverflow.com/questions/78987023/source-generated-valueconverter-with-ef-core
[33] Source generator with dependency : r/csharp https://www.reddit.com/r/csharp/comments/kledw3/source_generator_with_dependency/
[34] Manual: Create and use a source generator https://docs.unity3d.com/6000.2/Documentation/Manual/create-source-generator.html
[35] Let's Build an Incremental Source Generator With Roslyn ... https://www.youtube.com/watch?v=azJm_Y2nbAI
[36] Using MSBuild Items and Properties in C# 9 Source ... https://platform.uno/blog/using-msbuild-items-and-properties-in-c-9-source-generators/
[37] Reverse Engineering Existing Databases with Entity ... https://blog.jetbrains.com/dotnet/2023/07/20/reverse-engineering-existing-databases-with-entity-framework-core/
[38] Source generator - Microsoft Q&A https://learn.microsoft.com/en-sg/answers/questions/2281988/source-generator
[39] Structuring a .NET Core 9 Blazor + API Architecture for ... https://learn.microsoft.com/en-us/answers/questions/5544857/structuring-a-net-core-9-blazor-api-architecture-f
[40] Use multiple project in c# source generator https://stackoverflow.com/questions/65508732/use-multiple-project-in-c-sharp-source-generator
[41] neozhu/CleanArchitectureWithBlazorServer https://github.com/neozhu/CleanArchitectureWithBlazorServer
[42] How to Test Roslyn Source Generators - Gérald Barré https://www.meziantou.net/how-to-test-roslyn-source-generators.htm
[43] Building a Blazor Frontend with API for Separate Backend ... https://www.reddit.com/r/csharp/comments/1fax0c7/help_needed_building_a_blazor_frontend_with_api/
[44] Source generator - how to reference a project? #48746 https://github.com/dotnet/roslyn/discussions/48746
[45] ASP.NET Core Blazor project structure https://learn.microsoft.com/en-us/aspnet/core/blazor/project-structure?view=aspnetcore-9.0
[46] Configuration in ASP.NET Core https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-9.0
[47] Building a Clean Architecture with Blazor https://dotnet8.patrickgod.com/posts/building-a-clean-architecture-with-blazor
[48] Incremental Roslyn Source Generators: Using Additional ... https://www.thinktecture.com/net/roslyn-source-generators-using-additional-files/
[49] Blazor Fundamentals #5 - Building a Backend API https://www.youtube.com/watch?v=IyGvEEK24i4
[50] Blazor Hero - Clean Architecture Template Quick Start Guide https://codewithmukesh.com/blog/blazor-hero-quick-start-guide/
