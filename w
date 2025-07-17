Вот пошаговое решение для создания приложения на .NET 8, объединяющего Blazor Server, OData и Swagger:

### 1. Создайте новый проект
```bash
dotnet new blazorserver -n BlazorODataApp
cd BlazorODataApp
```

### 2. Установите необходимые пакеты
```bash
dotnet add package Microsoft.AspNetCore.OData
dotnet add package Swashbuckle.AspNetCore
dotnet add package Microsoft.AspNetCore.OData.Versioning.ApiExplorer
```

### 3. Настройка Program.cs
```csharp
using Microsoft.AspNetCore.OData;
using Microsoft.OData.Edm;
using Microsoft.OData.ModelBuilder;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Добавление сервисов
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();

// Добавление контроллеров и OData
builder.Services.AddControllers()
    .AddOData(opt => 
    {
        opt.AddRouteComponents("odata", GetEdmModel());
        opt.Select().Filter().OrderBy().Expand().Count().SetMaxTop(100);
    });

// Настройка Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Blazor OData API", Version = "v1" });
    
    // Для поддержки OData в Swagger
    c.AddODataSwaggerSupport();
});

// Создаем сервис с тестовыми данными
builder.Services.AddSingleton<WeatherService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "Blazor OData API v1"));
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.MapControllers(); // Для OData API
app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

app.Run();

// Создание EDM модели для OData
static IEdmModel GetEdmModel()
{
    var builder = new ODataConventionModelBuilder();
    builder.EntitySet<WeatherForecast>("WeatherForecast");
    return builder.GetEdmModel();
}
```

### 4. Модель данных (Models/WeatherForecast.cs)
```csharp
public class WeatherForecast
{
    public int Id { get; set; }
    public DateTime Date { get; set; }
    public int TemperatureC { get; set; }
    public string? Summary { get; set; }
    
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
```

### 5. Сервис данных (Services/WeatherService.cs)
```csharp
public class WeatherService
{
    private static readonly string[] Summaries = new[]
    {
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    };

    public List<WeatherForecast> Forecasts { get; } = new();

    public WeatherService()
    {
        var startDate = DateOnly.FromDateTime(DateTime.Now);
        Forecasts = Enumerable.Range(1, 100).Select(index => new WeatherForecast
        {
            Id = index,
            Date = startDate.AddDays(index).ToDateTime(TimeOnly.MinValue),
            TemperatureC = Random.Shared.Next(-20, 55),
            Summary = Summaries[Random.Shared.Next(Summaries.Length)]
        }).ToList();
    }
}
```

### 6. Контроллер OData (Controllers/WeatherForecastController.cs)
```csharp
using Microsoft.AspNetCore.OData.Query;
using Microsoft.AspNetCore.OData.Routing.Controllers;

public class WeatherForecastController : ODataController
{
    private readonly WeatherService _service;

    public WeatherForecastController(WeatherService service)
    {
        _service = service;
    }

    [EnableQuery]
    public IActionResult Get()
    {
        return Ok(_service.Forecasts.AsQueryable());
    }
}
```

### 7. Добавьте поддержку OData в Swagger (Extensions/ODataSwaggerSupport.cs)
```csharp
using Microsoft.AspNetCore.OData.Routing;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

public class ODataOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        if (context.ApiDescription.ActionDescriptor.EndpointMetadata.OfType<ODataRoutingMetadata>().Any())
        {
            operation.Parameters ??= new List<OpenApiParameter>();
            operation.Parameters.Add(new OpenApiParameter
            {
                Name = "$select",
                In = ParameterLocation.Query,
                Schema = new OpenApiSchema { Type = "string" },
                Description = "Select properties"
            });
            
            // Добавьте другие параметры OData по необходимости
        }
    }
}

public static class SwaggerExtensions
{
    public static void AddODataSwaggerSupport(this SwaggerGenOptions options)
    {
        options.OperationFilter<ODataOperationFilter>();
    }
}
```

### 8. Настройте маршрутизацию (Pages/_Host.cshtml)
```html
@page "/"
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
@{
    Layout = "_Layout";
}

<component type="typeof(App)" render-mode="ServerPrerendered" />
```

### Запуск приложения
```bash
dotnet run
```

### Тестирование:
1. Blazor UI: `https://localhost:5001`
2. OData Endpoint: `https://localhost:5001/odata/WeatherForecast`
3. Swagger UI: `https://localhost:5001/swagger`

### Особенности реализации:
1. **Совместимость роутинга**:
   - Blazor: `/`
   - OData: `/odata/`
   - Swagger: `/swagger`

2. **Поддержка OData запросов**:
   ```http
   GET /odata/WeatherForecast?$filter=TemperatureC gt 30&$orderby=Date desc
   ```

3. **Долговременная работа**:
   - Используется стабильный DI-контейнер
   - Асинхронные операции
   - Оптимизированная модель данных

4. **Расширяемость**:
   - Модульная архитектура
   - Четкое разделение слоев
   - Поддержка новых сущностей через добавление в EDM модель

Для увеличения производительности в production:
1. Настройте кэширование OData
2. Используйте `IQueryable` для работы с БД
3. Добавьте авторизацию
4. Настройте rate-limiting
5. Используйте сжатие ответов