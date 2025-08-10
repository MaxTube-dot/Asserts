[GenerateBlazorComponents(GenerateCRUD = true, RoutePrefix = "admin/data")]
public class ApplicationDbContext : DbContext
{
    // Ваши DbSets
    public DbSet<Product> Products { get; set; }
    public DbSet<Category> Categories { get; set; }
}# Полный код генератора Blazor страниц из DbContext

Я предоставлю полный код для генерации Blazor (Razor Components) страниц вместо Razor Pages. Вот готовая реализация:

## 1. Структура проекта генератора

```
BlazorComponentsGenerator/
├── BlazorComponentsGenerator.csproj
├── DbContextSyntaxReceiver.cs
├── BlazorComponentsGenerator.cs
├── Templates/
│   ├── ListComponentTemplate.razor
│   └── EditComponentTemplate.razor
└── Properties/
    └── AssemblyInfo.cs
```

## 2. Файлы генератора

### 2.1. BlazorComponentsGenerator.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <EnforceExtendedAnalyzerRules>true</EnforceExtendedAnalyzerRules>
    <IsRoslynComponent>true</IsRoslynComponent>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp" Version="4.3.1" PrivateAssets="all" />
    <PackageReference Include="Microsoft.CodeAnalysis.Analyzers" Version="3.3.3" PrivateAssets="all" />
    <PackageReference Include="Microsoft.AspNetCore.Components" Version="6.0.0" PrivateAssets="all" />
  </ItemGroup>

  <ItemGroup>
    <EmbeddedResource Include="Templates/*.razor" />
  </ItemGroup>

</Project>
```

### 2.2. DbContextSyntaxReceiver.cs

```csharp
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace BlazorComponentsGenerator;

public class DbContextSyntaxReceiver : ISyntaxReceiver
{
    public ClassDeclarationSyntax DbContextClass { get; private set; }

    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is ClassDeclarationSyntax classDeclaration)
        {
            if (classDeclaration.BaseList?.Types.Any(t => 
                t.Type.ToString().Contains("DbContext")) == true)
            {
                DbContextClass = classDeclaration;
            }
        }
    }
}
```

### 2.3. BlazorComponentsGenerator.cs

```csharp
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Text;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;

namespace BlazorComponentsGenerator;

[Generator]
public class BlazorComponentsGenerator : ISourceGenerator
{
    public void Initialize(GeneratorInitializationContext context)
    {
#if DEBUG
        if (!Debugger.IsAttached)
        {
            Debugger.Launch();
        }
#endif

        context.RegisterForSyntaxNotifications(() => new DbContextSyntaxReceiver());
    }

    public void Execute(GeneratorExecutionContext context)
    {
        if (context.SyntaxReceiver is not DbContextSyntaxReceiver receiver)
            return;

        var compilation = context.Compilation;
        var dbContextSymbol = GetDbContextSymbol(compilation, receiver);
        if (dbContextSymbol == null) return;

        var generateAttr = dbContextSymbol.GetAttributes()
            .FirstOrDefault(a => a.AttributeClass?.Name == "GenerateBlazorComponentsAttribute");

        var generateCRUD = generateAttr?.NamedArguments
            .FirstOrDefault(a => a.Key == "GenerateCRUD").Value.Value as bool? ?? true;

        var routePrefix = generateAttr?.NamedArguments
            .FirstOrDefault(a => a.Key == "RoutePrefix").Value.Value as string ?? "data";

        var dbSets = GetDbSetProperties(dbContextSymbol);

        foreach (var dbSet in dbSets)
        {
            var entityType = GetEntityType(dbSet.Type);
            if (entityType == null) continue;

            GenerateListComponent(context, entityType, routePrefix);
            
            if (generateCRUD)
            {
                GenerateEditComponent(context, entityType, routePrefix);
            }
        }
    }

    private void GenerateListComponent(GeneratorExecutionContext context, ITypeSymbol entityType, string routePrefix)
    {
        string entityName = entityType.Name;
        string componentCode = LoadTemplate("ListComponentTemplate.razor")
            .Replace("{{EntityName}}", entityName)
            .Replace("{{RoutePrefix}}", routePrefix)
            .Replace("{{FullTypeName}}", entityType.ToDisplayString());

        context.AddSource($"{routePrefix}/{entityName}List.razor.g.cs", 
            SourceText.From(componentCode, Encoding.UTF8));
    }

    private void GenerateEditComponent(GeneratorExecutionContext context, ITypeSymbol entityType, string routePrefix)
    {
        string entityName = entityType.Name;
        string componentCode = LoadTemplate("EditComponentTemplate.razor")
            .Replace("{{EntityName}}", entityName)
            .Replace("{{RoutePrefix}}", routePrefix)
            .Replace("{{FullTypeName}}", entityType.ToDisplayString());

        context.AddSource($"{routePrefix}/{entityName}Edit.razor.g.cs", 
            SourceText.From(componentCode, Encoding.UTF8));
    }

    private string LoadTemplate(string name)
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = $"BlazorComponentsGenerator.Templates.{name}";
        
        using var stream = assembly.GetManifestResourceStream(resourceName);
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }

    private INamedTypeSymbol GetDbContextSymbol(Compilation compilation, DbContextSyntaxReceiver receiver)
    {
        if (receiver.DbContextClass == null) return null;
        
        var model = compilation.GetSemanticModel(receiver.DbContextClass.SyntaxTree);
        return model.GetDeclaredSymbol(receiver.DbContextClass) as INamedTypeSymbol;
    }

    private IEnumerable<IPropertySymbol> GetDbSetProperties(INamedTypeSymbol dbContextSymbol)
    {
        return dbContextSymbol.GetMembers()
            .OfType<IPropertySymbol>()
            .Where(p => p.Type is INamedTypeSymbol namedType && 
                       namedType.ConstructedFrom?.ToDisplayString() == "Microsoft.EntityFrameworkCore.DbSet<T>");
    }

    private INamedTypeSymbol GetEntityType(ITypeSymbol dbSetType)
    {
        if (dbSetType is INamedTypeSymbol namedType && 
            namedType.IsGenericType && 
            namedType.TypeArguments.Length == 1)
        {
            return namedType.TypeArguments[0] as INamedTypeSymbol;
        }
        return null;
    }
}
```

### 2.4. Templates/ListComponentTemplate.razor

```razor
@page "/{{RoutePrefix}}/{{EntityName}}"
@inject YourDbContext Context
@inject NavigationManager Navigation

<h3>{{EntityName}} List</h3>

<table class="table">
    <thead>
        <tr>
            @foreach (var prop in typeof({{FullTypeName}}).GetProperties())
            {
                <th>@prop.Name</th>
            }
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        @foreach (var item in items)
        {
            <tr>
                @foreach (var prop in typeof({{FullTypeName}}).GetProperties())
                {
                    <td>@prop.GetValue(item)</td>
                }
                <td>
                    <button @onclick="() => EditItem(item.Id)" class="btn btn-sm btn-primary">Edit</button>
                </td>
            </tr>
        }
    </tbody>
</table>

<button @onclick="AddNew" class="btn btn-primary">Add New</button>

@code {
    private List<{{FullTypeName}}> items = new();

    protected override async Task OnInitializedAsync()
    {
        items = await Context.Set<{{FullTypeName}}>().ToListAsync();
    }

    private void EditItem(int id)
    {
        Navigation.NavigateTo($"/{{RoutePrefix}}/{{EntityName}}/{id}");
    }

    private void AddNew()
    {
        Navigation.NavigateTo($"/{{RoutePrefix}}/{{EntityName}}/0");
    }
}
```

### 2.5. Templates/EditComponentTemplate.razor

```razor
@page "/{{RoutePrefix}}/{{EntityName}}/{Id:int}"
@inject YourDbContext Context
@inject NavigationManager Navigation

<h3>@(Id == 0 ? "Create" : "Edit") {{EntityName}}</h3>

<EditForm Model="item" OnValidSubmit="HandleValidSubmit">
    <DataAnnotationsValidator />
    <ValidationSummary />

    <div class="form-group">
        @foreach (var prop in typeof({{FullTypeName}}).GetProperties())
        {
            @if (prop.Name != "Id")
            {
                <div class="form-group">
                    <label>@prop.Name</label>
                    @if (prop.PropertyType == typeof(string))
                    {
                        <InputText @bind-Value="@item.@prop.Name" class="form-control" />
                    }
                    else if (prop.PropertyType == typeof(bool))
                    {
                        <InputCheckbox @bind-Value="@item.@prop.Name" class="form-check-input" />
                    }
                    else if (prop.PropertyType.IsEnum)
                    {
                        <InputSelect @bind-Value="@item.@prop.Name" class="form-control">
                            @foreach (var value in Enum.GetValues(prop.PropertyType))
                            {
                                <option value="@value">@value</option>
                            }
                        </InputSelect>
                    }
                    else
                    {
                        <InputNumber @bind-Value="@item.@prop.Name" class="form-control" />
                    }
                    <ValidationMessage For="@(() => item.@prop.Name)" />
                </div>
            }
        }
    </div>

    <button type="submit" class="btn btn-primary">Save</button>
    <button @onclick="Cancel" class="btn btn-secondary">Cancel</button>
</EditForm>

@code {
    [Parameter]
    public int Id { get; set; }

    private {{FullTypeName}} item = new();

    protected override async Task OnInitializedAsync()
    {
        if (Id != 0)
        {
            item = await Context.Set<{{FullTypeName}}>().FindAsync(Id);
            if (item == null)
            {
                Navigation.NavigateTo("/{{RoutePrefix}}/{{EntityName}}");
            }
        }
    }

    private async Task HandleValidSubmit()
    {
        if (Id == 0)
        {
            Context.Add(item);
        }
        else
        {
            Context.Update(item);
        }

        await Context.SaveChangesAsync();
        Navigation.NavigateTo("/{{RoutePrefix}}/{{EntityName}}");
    }

    private void Cancel()
    {
        Navigation.NavigateTo("/{{RoutePrefix}}/{{EntityName}}");
    }
}
```

## 3. Как использовать

1. Добавьте атрибут к вашему DbContext:

```csharp
[GenerateBlazorComponents(GenerateCRUD = true, RoutePrefix = "data")]
public class YourDbContext : DbContext
{
    // Ваши DbSets
}
```

2. Добавьте ссылку на генератор в ваш Blazor проект:

```xml
<ItemGroup>
    <ProjectReference Include="..\BlazorComponentsGenerator\BlazorComponentsGenerator.csproj" 
                      OutputItemType="Analyzer" 
                      ReferenceOutputAssembly="false" />
</ItemGroup>
```

3. Добавьте маршруты в `App.razor`:

```razor
<Router AppAssembly="@typeof(Program).Assembly">
    <!-- Другие маршруты -->
</Router>
```

4. При компиляции проекта будут автоматически сгенерированы Blazor компоненты для всех DbSet в вашем контексте.

## 4. Особенности реализации

1. Генератор создает полноценные CRUD компоненты с:
   - Списком сущностей
   - Формой редактирования
   - Валидацией
   - Навигацией

2. Поддерживаются различные типы свойств:
   - Строки
   - Числа
   - Boolean
   - Enum

3. Маршруты генерируются по шаблону:
   - `/data/EntityName` - список
   - `/data/EntityName/{id}` - редактирование

4. Для работы требуется инъекция YourDbContext в компоненты

Этот генератор автоматически создаст все необходимые Blazor компоненты при каждом изменении вашего DbContext, значительно ускоряя разработку стандартных CRUD интерфейсов.