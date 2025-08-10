# Полный код инкрементального генератора Blazor-страниц

Вот готовое решение с инкрементальным генератором, включая все необходимые компоненты:

## 1. GenerateBlazorComponentsAttribute.cs

```csharp
using System;

namespace BlazorComponentsGenerator
{
    [AttributeUsage(AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
    public sealed class GenerateBlazorComponentsAttribute : Attribute
    {
        public bool GenerateCRUD { get; set; } = true;
        public string RoutePrefix { get; set; } = "data";
        public bool GenerateList { get; set; } = true;
    }
}
```

## 2. BlazorComponentsIncrementalGenerator.cs

```csharp
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Text;
using System.Collections.Immutable;
using System.Linq;
using System.Text;

namespace BlazorComponentsGenerator
{
    [Generator]
    public class BlazorComponentsIncrementalGenerator : IIncrementalGenerator
    {
        public void Initialize(IncrementalGeneratorInitializationContext context)
        {
            var dbContextProvider = context.SyntaxProvider
                .CreateSyntaxProvider(
                    predicate: static (node, _) => node is ClassDeclarationSyntax cds && 
                                                  cds.BaseList?.Types.Any(t => t.Type.ToString().Contains("DbContext")) == true,
                    transform: static (ctx, _) => (ClassDeclarationSyntax)ctx.Node)
                .Where(static c => c is not null);

            var compilationAndDbContexts = context.CompilationProvider.Combine(dbContextProvider.Collect());

            context.RegisterSourceOutput(compilationAndDbContexts, 
                static (spc, source) => Execute(source.Left, source.Right, spc));
        }

        private static void Execute(
            Compilation compilation,
            ImmutableArray<ClassDeclarationSyntax> dbContextClasses,
            SourceProductionContext context)
        {
            foreach (var dbContextClass in dbContextClasses)
            {
                var semanticModel = compilation.GetSemanticModel(dbContextClass.SyntaxTree);
                var dbContextSymbol = semanticModel.GetDeclaredSymbol(dbContextClass);

                if (dbContextSymbol is null) continue;

                var generateAttr = dbContextSymbol.GetAttributes()
                    .FirstOrDefault(a => a.AttributeClass?.Name == nameof(GenerateBlazorComponentsAttribute));

                var routePrefix = GetAttributeValue(generateAttr, "RoutePrefix", "data");
                var generateCRUD = GetAttributeValue(generateAttr, "GenerateCRUD", true);
                var generateList = GetAttributeValue(generateAttr, "GenerateList", true);

                foreach (var member in dbContextSymbol.GetMembers())
                {
                    if (member is IPropertySymbol { Type: INamedTypeSymbol typeSymbol } && 
                        typeSymbol.ConstructedFrom?.ToDisplayString() == "Microsoft.EntityFrameworkCore.DbSet<T>")
                    {
                        var entityType = typeSymbol.TypeArguments[0] as INamedTypeSymbol;
                        if (entityType is null) continue;

                        if (generateList)
                        {
                            GenerateListComponent(context, entityType, routePrefix);
                        }

                        if (generateCRUD)
                        {
                            GenerateEditComponent(context, entityType, routePrefix);
                        }
                    }
                }
            }
        }

        private static T GetAttributeValue<T>(AttributeData? attribute, string propertyName, T defaultValue)
        {
            if (attribute is null) return defaultValue;
            
            var arg = attribute.NamedArguments.FirstOrDefault(a => a.Key == propertyName);
            return arg.Value.Value is T value ? value : defaultValue;
        }

        private static void GenerateListComponent(
            SourceProductionContext context,
            INamedTypeSymbol entityType,
            string routePrefix)
        {
            var entityName = entityType.Name;
            var code = $$"""
                @page "/{{routePrefix}}/{{entityName}}"
                @inject YourNamespace.Data.YourDbContext Context
                @inject Microsoft.AspNetCore.Components.NavigationManager Navigation

                <h3>{{entityName}} List</h3>

                <table class="table">
                    <thead>
                        <tr>
                            @foreach (var prop in typeof({{entityType.ToDisplayString()}}).GetProperties())
                            {
                                <th>@prop.Name</th>
                            }
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach (var item in _items)
                        {
                            <tr>
                                @foreach (var prop in typeof({{entityType.ToDisplayString()}}).GetProperties())
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
                    private List<{{entityType.ToDisplayString()}}> _items = new();

                    protected override async Task OnInitializedAsync()
                    {
                        _items = await Context.Set<{{entityType.ToDisplayString()}}>().ToListAsync();
                    }

                    private void EditItem(int id)
                    {
                        Navigation.NavigateTo($"/{{routePrefix}}/{{entityName}}/{id}");
                    }

                    private void AddNew()
                    {
                        Navigation.NavigateTo($"/{{routePrefix}}/{{entityName}}/0");
                    }
                }
                """;

            context.AddSource($"{entityName}List.razor.g.cs", SourceText.From(code, Encoding.UTF8));
        }

        private static void GenerateEditComponent(
            SourceProductionContext context,
            INamedTypeSymbol entityType,
            string routePrefix)
        {
            var entityName = entityType.Name;
            var code = $$"""
                @page "/{{routePrefix}}/{{entityName}}/{{"{"}}Id{{"}"}}"
                @inject YourNamespace.Data.YourDbContext Context
                @inject Microsoft.AspNetCore.Components.NavigationManager Navigation

                <h3>@(Id == 0 ? "Create" : "Edit") {{entityName}}</h3>

                <EditForm Model="_item" OnValidSubmit="HandleValidSubmit">
                    <DataAnnotationsValidator />
                    <ValidationSummary />

                    @foreach (var prop in typeof({{entityType.ToDisplayString()}}).GetProperties())
                    {
                        @if (prop.Name != "Id")
                        {
                            <div class="form-group">
                                <label>@prop.Name</label>
                                @if (prop.PropertyType == typeof(string))
                                {
                                    <InputText @bind-Value="_item.@prop.Name" class="form-control" />
                                }
                                else if (prop.PropertyType == typeof(bool))
                                {
                                    <InputCheckbox @bind-Value="_item.@prop.Name" class="form-check-input" />
                                }
                                else if (prop.PropertyType.IsEnum)
                                {
                                    <InputSelect @bind-Value="_item.@prop.Name" class="form-control">
                                        @foreach (var value in Enum.GetValues(prop.PropertyType))
                                        {
                                            <option value="@value">@value</option>
                                        }
                                    </InputSelect>
                                }
                                else
                                {
                                    <InputNumber @bind-Value="_item.@prop.Name" class="form-control" />
                                }
                                <ValidationMessage For="@(() => _item.@prop.Name)" />
                            </div>
                        }
                    }

                    <button type="submit" class="btn btn-primary">Save</button>
                    <button @onclick="Cancel" class="btn btn-secondary">Cancel</button>
                </EditForm>

                @code {
                    [Parameter]
                    public int Id { get; set; }

                    private {{entityType.ToDisplayString()}} _item = new();

                    protected override async Task OnInitializedAsync()
                    {
                        if (Id != 0)
                        {
                            _item = await Context.Set<{{entityType.ToDisplayString()}}>().FindAsync(Id);
                            if (_item == null)
                            {
                                Navigation.NavigateTo("/{{routePrefix}}/{{entityName}}");
                            }
                        }
                    }

                    private async Task HandleValidSubmit()
                    {
                        if (Id == 0)
                        {
                            Context.Add(_item);
                        }
                        else
                        {
                            Context.Update(_item);
                        }

                        await Context.SaveChangesAsync();
                        Navigation.NavigateTo("/{{routePrefix}}/{{entityName}}");
                    }

                    private void Cancel()
                    {
                        Navigation.NavigateTo("/{{routePrefix}}/{{entityName}}");
                    }
                }
                """;

            context.AddSource($"{entityName}Edit.razor.g.cs", SourceText.From(code, Encoding.UTF8));
        }
    }
}
```

## 3. BlazorComponentsGenerator.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <EnforceExtendedAnalyzerRules>true</EnforceExtendedAnalyzerRules>
    <IsRoslynComponent>true</IsRoslynComponent>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp" Version="4.3.1" PrivateAssets="all" />
    <PackageReference Include="Microsoft.CodeAnalysis.Analyzers" Version="3.3.3" PrivateAssets="all" />
    <PackageReference Include="Microsoft.AspNetCore.Components" Version="6.0.0" PrivateAssets="all" />
  </ItemGroup>

</Project>
```

## Как использовать:

1. Добавьте атрибут к DbContext:

```csharp
[GenerateBlazorComponents(
    RoutePrefix = "admin/data",
    GenerateCRUD = true,
    GenerateList = true)]
public class AppDbContext : DbContext
{
    public DbSet<Product> Products { get; set; }
    public DbSet<Category> Categories { get; set; }
}
```

2. Подключите генератор в основном проекте:

```xml
<ItemGroup>
  <ProjectReference Include="..\BlazorComponentsGenerator\BlazorComponentsGenerator.csproj" 
                   OutputItemType="Analyzer" 
                   ReferenceOutputAssembly="false" />
</ItemGroup>
```

3. Добавьте маршрутизацию в `App.razor`:

```razor
<Router AppAssembly="@typeof(Program).Assembly" />
```

## Особенности реализации:

1. Полностью инкрементальный генератор с кэшированием
2. Поддержка настройки через атрибут
3. Генерация как списков, так и форм редактирования
4. Автоматическая обработка разных типов свойств
5. Оптимизированная работа с символами Roslyn

Генератор создаст компоненты для всех DbSet при каждой сборке, учитывая только измененные файлы.