Вот модифицированное решение для WebAPI приложения, которое включает:

1. Генерацию DTO классов
2. Настройку DI для работы с PostgREST
3. Пример контроллера

### 1. Установите необходимые NuGet пакеты:

```bash
dotnet add package Microsoft.OpenApi --version 1.2.3
dotnet add package Newtonsoft.Json --version 13.0.3
dotnet add package System.Text.Json --version 6.0.0
dotnet add package Microsoft.Extensions.Http --version 6.0.0
```

### 2. Код для WebAPI приложения:

#### `Program.cs` (или `Startup.cs` для .NET 5)

```csharp
using Microsoft.OpenApi.Models;
using Microsoft.OpenApi.Readers;
using System.Net.Http;

var builder = WebApplication.CreateBuilder(args);

// Добавляем HttpClient для работы с PostgREST
builder.Services.AddHttpClient("Postgrest", client =>
{
    client.BaseAddress = new Uri(builder.Configuration["Postgrest:BaseUrl"] ?? "http://localhost:3000");
});

// Регистрируем сервис для работы с DTO
builder.Services.AddSingleton<IDtoGenerator, DtoGenerator>();

// Добавляем контроллеры
builder.Services.AddControllers();

// Настройка Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

#### `DtoGenerator.cs` (Сервис для генерации DTO)

```csharp
using Microsoft.OpenApi.Models;
using System.Text;

public interface IDtoGenerator
{
    Task<string> GenerateDtoClass(string entityName);
    Task<IEnumerable<string>> GetAllEntityNames();
}

public class DtoGenerator : IDtoGenerator
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public DtoGenerator(IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    public async Task<IEnumerable<string>> GetAllEntityNames()
    {
        var document = await LoadOpenApiDocument();
        return document?.Components.Schemas.Keys ?? Enumerable.Empty<string>();
    }

    public async Task<string> GenerateDtoClass(string entityName)
    {
        var document = await LoadOpenApiDocument();
        if (document == null || !document.Components.Schemas.TryGetValue(entityName, out var schema))
        {
            return null;
        }

        return GenerateClassCode(entityName, schema);
    }

    private async Task<OpenApiDocument> LoadOpenApiDocument()
    {
        var client = _httpClientFactory.CreateClient("Postgrest");
        try
        {
            var response = await client.GetStreamAsync("/openapi.json");
            var openApiReader = new OpenApiStreamReader();
            return openApiReader.Read(response, out _);
        }
        catch
        {
            return null;
        }
    }

    private string GenerateClassCode(string className, OpenApiSchema schema)
    {
        var sb = new StringBuilder();
        
        sb.AppendLine("using System;");
        sb.AppendLine("using System.Text.Json.Serialization;");
        sb.AppendLine();
        sb.AppendLine("namespace YourProject.DTOs");
        sb.AppendLine("{");
        sb.AppendLine($"    public class {ToPascalCase(className)}");
        sb.AppendLine("    {");

        foreach (var property in schema.Properties)
        {
            sb.AppendLine("        [JsonPropertyName(\"" + property.Key + "\")]");
            sb.AppendLine($"        public {MapOpenApiTypeToCSharpType(property.Value)} {ToPascalCase(property.Key)} {{ get; set; }}");
            sb.AppendLine();
        }

        sb.AppendLine("    }");
        sb.AppendLine("}");
        
        return sb.ToString();
    }

    private string MapOpenApiTypeToCSharpType(OpenApiSchema schema)
    {
        // Реализация как в предыдущем примере
    }

    private string ToPascalCase(string input)
    {
        // Реализация как в предыдущем примере
    }
}
```

#### `EntitiesController.cs` (Пример контроллера)

```csharp
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/[controller]")]
public class EntitiesController : ControllerBase
{
    private readonly IDtoGenerator _dtoGenerator;

    public EntitiesController(IDtoGenerator dtoGenerator)
    {
        _dtoGenerator = dtoGenerator;
    }

    [HttpGet]
    public async Task<IActionResult> GetAllEntities()
    {
        var entities = await _dtoGenerator.GetAllEntityNames();
        return Ok(entities);
    }

    [HttpGet("{entityName}/dto")]
    public async Task<IActionResult> GetDtoForEntity(string entityName)
    {
        var dtoCode = await _dtoGenerator.GenerateDtoClass(entityName);
        if (dtoCode == null)
        {
            return NotFound();
        }
        return Content(dtoCode, "text/plain");
    }
}
```

#### `PostgrestController.cs` (Пример контроллера для работы с PostgREST)

```csharp
using Microsoft.AspNetCore.Mvc;
using System.Net.Http;

[ApiController]
[Route("api/[controller]")]
public class PostgrestController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;

    public PostgrestController(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    [HttpGet("{entity}")]
    public async Task<IActionResult> GetEntities(string entity)
    {
        var client = _httpClientFactory.CreateClient("Postgrest");
        var response = await client.GetAsync($"/{entity}");
        
        if (!response.IsSuccessStatusCode)
        {
            return StatusCode((int)response.StatusCode);
        }

        var content = await response.Content.ReadAsStringAsync();
        return Content(content, "application/json");
    }
}
```

### 3. Настройка в `appsettings.json`

```json
{
  "Postgrest": {
    "BaseUrl": "http://localhost:3000"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

### Как это работает:

1. **Генерация DTO**:
   - Сервис `DtoGenerator` загружает OpenAPI спецификацию
   - Преобразует схемы в C# DTO классы
   - Доступ через `/api/entities/{entityName}/dto`

2. **Доступ к PostgREST**:
   - Контроллер `PostgrestController` проксирует запросы к PostgREST
   - Например: `/api/postgrest/users` → `http://localhost:3000/users`

3. **Интеграция**:
   - Использует стандартный HttpClient с DI
   - Поддерживает Swagger для документации API

### Дополнительные улучшения:

1. Добавьте кэширование OpenAPI спецификации
2. Реализуйте авторизацию для PostgREST
3. Добавьте валидацию DTO
4. Реализуйте пагинацию для запросов

Это решение дает вам:
- Генерацию DTO на лету
- Прокси к PostgREST API
- Полностью интегрированное решение в ваше WebAPI приложение