# Динамическая фильтрация и загрузка данных в Blazor с IQueryable

Для создания гибкой реализации динамической фильтрации и загрузки связанных сущностей в Blazor приложении с **IQueryable**, можно использовать несколько подходов, которые позволят динамически определять поля для отображения и фильтрации без жесткого кодирования.

## Основные подходы к решению

### 1. Использование System.Linq.Dynamic.Core

**System.Linq.Dynamic.Core** — это мощная библиотека для создания динамических LINQ-запросов на основе строк[1][2]. Она позволяет строить запросы во время выполнения:

```csharp
// Установка пакета
Install-Package System.Linq.Dynamic.Core

// Динамический Where с параметрами
var query = context.Customers
    .Where("City == @0 and Orders.Count >= @1", "London", 10)
    .OrderBy("CompanyName")
    .Select("new(CompanyName as Name, Phone)");

// Динамическая фильтрация
var filteredData = dbContext.Products.AsQueryable()
    .Where(dynamicFilterExpression)
    .ToList();
```

### 2. Expression Trees для динамических запросов

Создание выражений во время выполнения с помощью Expression Trees[3][4]:

```csharp
public static class DynamicFilter
{
    public static Expression<Func<T, bool>> BuildPredicate<T>(
        string propertyName, 
        object value, 
        string operation)
    {
        var parameter = Expression.Parameter(typeof(T), "x");
        var property = Expression.Property(parameter, propertyName);
        var constant = Expression.Constant(value);
        
        Expression comparison = operation switch
        {
            "Equal" => Expression.Equal(property, constant),
            "Contains" => Expression.Call(property, "Contains", null, constant),
            "GreaterThan" => Expression.GreaterThan(property, constant),
            _ => throw new NotSupportedException($"Operation {operation} not supported")
        };
        
        return Expression.Lambda<Func<T, bool>>(comparison, parameter);
    }
}
```

### 3. Динамические Include для связанных сущностей

Для динамической загрузки связанных сущностей можно использовать расширения Entity Framework Core[5][6]:

```csharp
public static class DynamicIncludeExtensions
{
    public static IQueryable<T> DynamicInclude<T>(
        this IQueryable<T> query, 
        params string[] includeProperties) where T : class
    {
        return includeProperties.Aggregate(query, 
            (current, includeProperty) => current.Include(includeProperty));
    }
    
    // Использование
    var query = context.Orders
        .DynamicInclude("Customer", "OrderItems.Product")
        .Where(dynamicFilterExpression);
}
```

### 4. Динамическая Select проекция

Для выбора определенных полей во время выполнения[7]:

```csharp
public static class DynamicSelectExtensions
{
    public static IQueryable<ExpandoObject> DynamicSelect(
        this IQueryable source, 
        params string[] selectedFields)
    {
        var sourceType = source.ElementType;
        var properties = sourceType.GetProperties()
            .Where(p => selectedFields.Contains(p.Name))
            .ToArray();

        var parameter = Expression.Parameter(sourceType, "x");
        var bindings = properties.Select(prop =>
            Expression.Bind(
                typeof(ExpandoObject).GetProperty(prop.Name),
                Expression.Property(parameter, prop)
            ));

        var memberInit = Expression.MemberInit(
            Expression.New(typeof(ExpandoObject)), 
            bindings);

        var selector = Expression.Lambda(memberInit, parameter);
        return source.Provider.CreateQuery<ExpandoObject>(
            Expression.Call(typeof(Queryable), "Select", 
                new[] { sourceType, typeof(ExpandoObject) },
                source.Expression, selector));
    }
}
```

## Реализация для Blazor компонента

### Компонент для динамического отображения данных

```csharp
@using System.Reflection
@using System.Linq.Dynamic.Core
@using System.Dynamic
@typeparam TItem where TItem : class

<div class="dynamic-grid">
    @if (DisplayedColumns?.Any() == true && FilteredData?.Any() == true)
    {
        <table class="table">
            <thead>
                <tr>
                    @foreach (var column in DisplayedColumns)
                    {
                        <th>
                            @column.DisplayName
                            @if (column.Filterable)
                            {
                                <input @oninput="@(e => ApplyFilter(column.PropertyName, e.Value?.ToString()))" 
                                       placeholder="Filter..." />
                            }
                        </th>
                    }
                </tr>
            </thead>
            <tbody>
                @foreach (var item in FilteredData)
                {
                    <tr>
                        @foreach (var column in DisplayedColumns)
                        {
                            <td>@GetPropertyValue(item, column.PropertyName)</td>
                        }
                    </tr>
                }
            </tbody>
        </table>
    }
</div>

@code {
    [Parameter] public IQueryable<TItem> DataSource { get; set; } = null!;
    [Parameter] public List<ColumnDefinition> DisplayedColumns { get; set; } = new();
    [Parameter] public List<string> IncludeProperties { get; set; } = new();
    
    private List<TItem> FilteredData = new();
    private Dictionary<string, string> ActiveFilters = new();

    protected override async Task OnParametersSetAsync()
    {
        await LoadData();
    }

    private async Task LoadData()
    {
        var query = DataSource;
        
        // Динамически добавляем Include для связанных сущностей
        foreach (var include in IncludeProperties)
        {
            query = query.Include(include);
        }
        
        // Применяем активные фильтры
        if (ActiveFilters.Any())
        {
            var filterExpression = BuildFilterExpression();
            if (!string.IsNullOrEmpty(filterExpression))
            {
                query = query.Where(filterExpression, ActiveFilters.Values.ToArray());
            }
        }
        
        FilteredData = await query.ToListAsync();
    }

    private string BuildFilterExpression()
    {
        var conditions = ActiveFilters
            .Where(f => !string.IsNullOrEmpty(f.Value))
            .Select((f, index) => $"{f.Key}.Contains(@{index})")
            .ToList();
            
        return conditions.Any() ? string.Join(" && ", conditions) : string.Empty;
    }

    private async Task ApplyFilter(string propertyName, string? filterValue)
    {
        if (string.IsNullOrWhiteSpace(filterValue))
        {
            ActiveFilters.Remove(propertyName);
        }
        else
        {
            ActiveFilters[propertyName] = filterValue;
        }
        
        await LoadData();
    }

    private object? GetPropertyValue(TItem item, string propertyPath)
    {
        var properties = propertyPath.Split('.');
        object? value = item;
        
        foreach (var property in properties)
        {
            if (value == null) return null;
            
            var propertyInfo = value.GetType().GetProperty(property);
            value = propertyInfo?.GetValue(value);
        }
        
        return value;
    }
}

public class ColumnDefinition
{
    public string PropertyName { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public bool Filterable { get; set; } = true;
    public bool Sortable { get; set; } = true;
    public string? Format { get; set; }
}
```

### Сервис для динамической конфигурации

```csharp
public interface IDynamicDataService
{
    Task<List<ColumnDefinition>> GetColumnsForEntityAsync<T>();
    IQueryable<T> ApplyDynamicFiltering<T>(IQueryable<T> query, Dictionary<string, object> filters) where T : class;
    IQueryable<T> ApplyDynamicIncludes<T>(IQueryable<T> query, List<string> includes) where T : class;
}

public class DynamicDataService : IDynamicDataService
{
    public Task<List<ColumnDefinition>> GetColumnsForEntityAsync<T>()
    {
        var properties = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance);
        var columns = properties.Select(p => new ColumnDefinition
        {
            PropertyName = p.Name,
            DisplayName = GetDisplayName(p),
            Filterable = IsFilterable(p),
            Sortable = IsSortable(p)
        }).ToList();
        
        return Task.FromResult(columns);
    }

    public IQueryable<T> ApplyDynamicFiltering<T>(IQueryable<T> query, Dictionary<string, object> filters) where T : class
    {
        if (!filters?.Any() == true) return query;

        var filterExpressions = new List<string>();
        var parameters = new List<object>();
        var index = 0;

        foreach (var filter in filters.Where(f => f.Value != null))
        {
            var property = typeof(T).GetProperty(filter.Key);
            if (property == null) continue;

            if (property.PropertyType == typeof(string))
            {
                filterExpressions.Add($"{filter.Key}.Contains(@{index})");
            }
            else
            {
                filterExpressions.Add($"{filter.Key} == @{index}");
            }
            
            parameters.Add(filter.Value);
            index++;
        }

        if (filterExpressions.Any())
        {
            var combinedExpression = string.Join(" && ", filterExpressions);
            query = query.Where(combinedExpression, parameters.ToArray());
        }

        return query;
    }

    public IQueryable<T> ApplyDynamicIncludes<T>(IQueryable<T> query, List<string> includes) where T : class
    {
        return includes?.Aggregate(query, (current, include) => current.Include(include)) ?? query;
    }

    private string GetDisplayName(PropertyInfo property)
    {
        // Можно использовать атрибуты Display или создать собственную логику
        return property.Name;
    }

    private bool IsFilterable(PropertyInfo property)
    {
        // Логика определения возможности фильтрации
        var filterableTypes = new[] { typeof(string), typeof(int), typeof(DateTime), typeof(bool) };
        return filterableTypes.Contains(property.PropertyType) || 
               filterableTypes.Contains(Nullable.GetUnderlyingType(property.PropertyType));
    }

    private bool IsSortable(PropertyInfo property)
    {
        // Аналогично для сортировки
        return IsFilterable(property);
    }
}
```

### Использование компонента

```csharp
@page "/dynamic-data"
@inject ApplicationDbContext DbContext
@inject IDynamicDataService DynamicDataService

<DynamicDataGrid TItem="Product" 
                 DataSource="@GetProductsQuery()" 
                 DisplayedColumns="@columns" 
                 IncludeProperties="@includeProperties" />

@code {
    private List<ColumnDefinition> columns = new();
    private List<string> includeProperties = new() { "Category", "Supplier" };

    protected override async Task OnInitializedAsync()
    {
        columns = await DynamicDataService.GetColumnsForEntityAsync<Product>();
        
        // Можно динамически добавлять поля из связанных сущностей
        columns.Add(new ColumnDefinition 
        { 
            PropertyName = "Category.Name", 
            DisplayName = "Category Name" 
        });
    }

    private IQueryable<Product> GetProductsQuery()
    {
        return DbContext.Products.AsQueryable();
    }
}
```

## Преимущества данного подхода

1. **Гибкость**: Возможность динамически определять поля для отображения и фильтрации[8][9]
2. **Производительность**: Использование IQueryable позволяет EF Core оптимизировать запросы[5][10]
3. **Переиспользование**: Компонент работает с любыми сущностями
4. **Безопасность**: Expression Trees защищают от SQL-инъекций[11]
5. **Расширяемость**: Легко добавлять новые типы фильтров и операций

Этот подход позволяет создать мощную и гибкую систему для работы с данными в Blazor, которая может адаптироваться к различным требованиям без изменения основного кода.

Источники
[1] System.Linq.Dynamic.Core/README.md at master ... - GitHub https://github.com/zzzprojects/System.Linq.Dynamic.Core/blob/master/README.md
[2] Using Dynamic LINQ With System.Linq.Dynamic.Core Library - https://code-maze.com/using-dynamic-linq/
[3] C# - Creating Expression Trees for Dynamic Query Generation https://dev.to/theramoliya/c-creating-expression-trees-for-dynamic-query-generation-1o4j
[4] How to Build Dynamic Queries With Expression Trees in C# https://code-maze.com/dynamic-queries-expression-trees-csharp/
[5] Eager, Lazy and Explicit Loading with Entity Framework Core https://blog.jetbrains.com/dotnet/2023/09/21/eager-lazy-and-explicit-loading-with-entity-framework-core/
[6] Entity Framework Dynamic Include Hierarchy - CodeProject https://www.codeproject.com/Tips/1205294/Entity-Framework-Dynamic-Include-Hierarchy
[7] Creating dynamically select lambda methods using expressions with ... https://gist.github.com/mstrYoda/663789375b0df23e2662a53bebaf2c7c
[8] Column Rendering in Blazor DataGrid Component | Syncfusion https://blazor.syncfusion.com/documentation/datagrid/column-rendering
[9] Dynamic Querying in C#: Real-World Scenarios and Techniques https://dev.to/eriksoftwaredev/dynamic-querying-in-c-real-world-scenarios-and-techniques-66i
[10] Loading Related Data - EF Core - Microsoft Learn https://learn.microsoft.com/en-us/ef/core/querying/related-data/
[11] A Dynamic Where Implementation for Entity Framework - CodeProject https://www.codeproject.com/Articles/5358166/A-Dynamic-Where-Implementation-for-Entity-Framewor
[12] Can I get the dynamic linq string query from Data Filter - Radzen https://forum.radzen.com/t/can-i-get-the-dynamic-linq-string-query-from-data-filter/15805
[13] radzen-blazor/Radzen.Blazor/QueryableExtension.cs at master ... https://github.com/radzenhq/radzen-blazor/blob/master/Radzen.Blazor/QueryableExtension.cs
[14] Lazy Loading of Related Data - EF Core - Microsoft Learn https://learn.microsoft.com/en-us/ef/core/querying/related-data/lazy
[15] Dynamic columns when using SFDataManager | Blazor Forums https://www.syncfusion.com/forums/183405/dynamic-columns-when-using-sfdatamanager
[16] Howto implement a generic Filter for IQuerable for all Entities ? #2528 https://abp.io/support/questions/2528/Howto-implement-a-generic-Filter-for-IQuerable-for-all-Entities
[17] Data Loading in Entity Framework - DEV Community https://dev.to/grontis/data-loading-in-entity-framework-2foe
[18] Dynamic columns (Blazor) - Smart UI Components https://www.htmlelements.com/forums/topic/dynamic-columns-blazor/
[19] DataGrid Dynamic Columns and data - Radzen.Blazor Components https://forum.radzen.com/t/datagrid-dynamic-columns-and-data/10626
[20] How to filter data dynamically on radzen data grid based on Query ... https://learn.microsoft.com/en-us/answers/questions/1336934/how-to-filter-data-dynamically-on-radzen-data-grid
[21] Eager Loading of Related Data - EF Core | Microsoft Learn https://learn.microsoft.com/en-us/ef/core/querying/related-data/eager
[22] Grid for Blazor - How to create columns dynamically for DxGrid https://supportcenter.devexpress.com/ticket/details/t1079647/grid-for-blazor-how-to-create-columns-dynamically-for-dxgrid
[23] IQueryable: Creating dynamically an OR filtering - Stack Overflow https://stackoverflow.com/questions/3712803/iqueryable-creating-dynamically-an-or-filtering
[24] How can I load Child entities dynamically in Entity Framework 6 https://stackoverflow.com/questions/47265204/how-can-i-load-child-entities-dynamically-in-entity-framework-6
[25] MudBlazor with Dynamic Columns - Stack Overflow https://stackoverflow.com/questions/76522057/mudblazor-with-dynamic-columns
[26] Blazor DataFilter Component | Free UI Components by Radzen https://blazor.radzen.com/datafilter?theme=material3
[27] Loading Entities Dynamically with Entity Framework https://weblogs-3.asp.net/ricardoperes/loading-entities-dynamically-with-entity-framework
[28] EF Core 2.0 include nested entities with dynamic query https://stackoverflow.com/questions/48047010/ef-core-2-0-include-nested-entities-with-dynamic-query/48047159
[29] Class DynamicQueryableExtensions - GitHub Pages https://zzzprojects.github.io/System.Linq.Dynamic.Core/api/System.Linq.Dynamic.Core.DynamicQueryableExtensions.html
[30] Real-World Expression Trees: Dynamic Filtering in C# with Minimal ... https://dev.to/turalsuleymani/real-world-expression-trees-dynamic-filtering-in-c-with-minimal-api-2fdk
[31] Query Operators in Dynamic LINQ https://dynamic-linq.net/basic-query-operators
[32] Dynamic Sorting and Filtering in C# | Awaiting Bits https://blog.zhaytam.com/2020/05/17/dynamic-sorting-filtering-csharp/
[33] LINQ Dynamic in Entity Framework Plus (EF Plus) https://entityframework-plus.net/ef-core-linq-dynamic
[34] How to Build LINQ Queries based on run-time state - Microsoft Learn https://learn.microsoft.com/en-us/dotnet/csharp/linq/how-to-build-dynamic-queries
[35] zHaytam/DynamicExpressions: A dynamic expression ... - GitHub https://github.com/zHaytam/DynamicExpressions
[36] LINQ Dynamic - Entity Framework Extensions https://entityframework-extensions.net/linq-dynamic
[37] System.Linq.Dynamic.Core 1.6.7 - NuGet https://www.nuget.org/packages/System.Linq.Dynamic.Core
[38] Expression Trees - C# | Microsoft Learn https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/expression-trees/
[39] Dynamic Linq in Entity Framework Core - Stack Overflow https://stackoverflow.com/questions/72114614/dynamic-linq-in-entity-framework-core/72131028
[40] How to build a collection filter via expression trees in c# - Stack ... https://stackoverflow.com/questions/20400474/how-to-build-a-collection-filter-via-expression-trees-in-c-sharp
[41] Working with the Blazor DynamicComponent - Dave Brock https://www.daveabrock.com/2021/04/08/blazor-dynamic-component/
[42] Blazor Quick Grid - How to Create Table in Blazor - YouTube https://www.youtube.com/watch?v=aec2wUZmvmQ
[43] Recommended Approach For Dynamic Binding : r/Blazor - Reddit https://www.reddit.com/r/Blazor/comments/1kicobm/recommended_approach_for_dynamic_binding/
[44] Fast Dynamic Property/Field Accessors - CodeProject https://www.codeproject.com/Articles/14560/Fast-Dynamic-Property-Field-Accessors
[45] Blazor table component not updating dynamically - Stack Overflow https://stackoverflow.com/questions/72208403/blazor-table-component-not-updating-dynamically
[46] Easy reflection using a DynamicObject - Meziantou's blog https://www.meziantou.net/easy-reflection-using-a-dynamicobject.htm
[47] c# - Get properties of a Dynamic Type - Stack Overflow https://stackoverflow.com/questions/41613558/get-properties-of-a-dynamic-type/63061873
[48] How To Render Blazor Components Dynamically - Telerik.com https://www.telerik.com/blogs/how-to-render-blazor-components-dynamically
[49] Blazor hybrid binding to expando objects - Microsoft Q&A https://learn.microsoft.com/en-us/answers/questions/1013750/blazor-hybrid-binding-to-expando-objects
[50] c# - Getting a PropertyInfo of a dynamic object - Stack Overflow https://stackoverflow.com/questions/38058302/getting-a-propertyinfo-of-a-dynamic-object
[51] Render Component Dynamically in Blazor Using Built ... - CodeGuru https://www.codeguru.co.in/2022/06/render-component-dynamically-in-blazor.html
[52] Dynamic edit form generation from a generic entity : r/Blazor - Reddit https://www.reddit.com/r/Blazor/comments/1cz3frm/dynamic_edit_form_generation_from_a_generic_entity/
[53] Walkthrough: Creating and Using Dynamic Objects - C# https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/interop/walkthrough-creating-and-using-dynamic-objects
[54] Dynamically creating a table from a List datasource : r/Blazor - Reddit https://www.reddit.com/r/Blazor/comments/du92kk/dynamically_creating_a_table_from_a_list/
[55] Dynamically-rendered ASP.NET Core Razor components https://learn.microsoft.com/en-us/aspnet/core/blazor/components/dynamiccomponent?view=aspnetcore-9.0
[56] PropertyInfo.GetValue Method (System.Reflection) | Microsoft Learn https://learn.microsoft.com/en-us/dotnet/api/system.reflection.propertyinfo.getvalue?view=net-9.0
[57] ASP.NET Core Blazor render modes - Microsoft Learn https://learn.microsoft.com/en-us/aspnet/core/blazor/components/render-modes?view=aspnetcore-9.0
[58] c# - Blazor - Reflection issue - Stack Overflow https://stackoverflow.com/questions/76205420/blazor-reflection-issue
[59] Exploring Reflection in C#: Dynamically Accessing Object Properties ... https://www.wgrow.com/Team-Notes/ArticleID/66/Exploring-Reflection-in-C-Dynamically-Accessing-Object-Properties-and-Database-Operations
