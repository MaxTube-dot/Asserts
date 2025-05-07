using System;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.OpenApi.Models;
using Microsoft.OpenApi.Readers;
using System.Linq;
using System.Collections.Generic;

class Program
{
    static async Task Main(string[] args)
    {
        // URL к OpenAPI спецификации PostgREST
        string openApiUrl = "http://localhost:3000/openapi.json";
        
        // Загружаем OpenAPI спецификацию
        var openApiDocument = await LoadOpenApiDocument(openApiUrl);
        
        if (openApiDocument != null)
        {
            // Анализируем сущности и связи
            AnalyzeDatabaseEntities(openApiDocument);
        }
    }

    static async Task<OpenApiDocument> LoadOpenApiDocument(string url)
    {
        using var httpClient = new HttpClient();
        try
        {
            var stream = await httpClient.GetStreamAsync(url);
            var openApiReader = new OpenApiStreamReader();
            var readResult = openApiReader.Read(stream, out var diagnostic);
            
            if (diagnostic.Errors.Count > 0)
            {
                Console.WriteLine("Ошибки при чтении OpenAPI:");
                foreach (var error in diagnostic.Errors)
                {
                    Console.WriteLine($"- {error.Message}");
                }
            }
            
            return readResult;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Ошибка при загрузке OpenAPI: {ex.Message}");
            return null;
        }
    }

    static void AnalyzeDatabaseEntities(OpenApiDocument document)
    {
        Console.WriteLine("=== Анализ сущностей БД ===");
        
        // Получаем все пути (эндпоинты API), которые соответствуют таблицам
        var entityPaths = document.Paths
            .Where(p => p.Key.StartsWith("/") && p.Key.Count(c => c == '/') == 1)
            .ToList();
        
        // Собираем информацию о сущностях
        var entities = new Dictionary<string, EntityInfo>();
        
        foreach (var path in entityPaths)
        {
            var entityName = path.Key.Trim('/');
            var entityInfo = new EntityInfo
            {
                Name = entityName,
                Columns = new List<ColumnInfo>(),
                Relations = new List<RelationInfo>()
            };
            
            // Получаем схему для этой сущности
            var schema = document.Components.Schemas
                .FirstOrDefault(s => s.Key.Equals(entityName, StringComparison.OrdinalIgnoreCase)).Value;
            
            if (schema != null)
            {
                // Анализируем свойства (колонки)
                foreach (var property in schema.Properties)
                {
                    var columnInfo = new ColumnInfo
                    {
                        Name = property.Key,
                        Type = MapOpenApiTypeToDbType(property.Value.Type),
                        IsRequired = schema.Required.Contains(property.Key)
                    };
                    
                    entityInfo.Columns.Add(columnInfo);
                    
                    // Проверяем, является ли это поле внешним ключом (по соглашению *_id)
                    if (property.Key.EndsWith("_id") && property.Value.Type == "integer")
                    {
                        var relatedEntity = property.Key[..^3]; // убираем "_id" в конце
                        entityInfo.Relations.Add(new RelationInfo
                        {
                            Type = "Many-to-One",
                            TargetEntity = relatedEntity,
                            ForeignKey = property.Key
                        });
                    }
                }
            }
            
            entities.Add(entityName, entityInfo);
        }
        
        // Выводим результаты анализа
        foreach (var entity in entities.Values)
        {
            Console.WriteLine($"\nСущность: {entity.Name}");
            Console.WriteLine("Колонки:");
            foreach (var column in entity.Columns)
            {
                Console.WriteLine($"- {column.Name}: {column.Type} {(column.IsRequired ? "(NOT NULL)" : "")}");
            }
            
            if (entity.Relations.Any())
            {
                Console.WriteLine("Связи:");
                foreach (var relation in entity.Relations)
                {
                    Console.WriteLine($"- {relation.Type} с {relation.TargetEntity} (FK: {relation.ForeignKey})");
                }
            }
        }
    }
    
    static string MapOpenApiTypeToDbType(string openApiType)
    {
        return openApiType switch
        {
            "integer" => "INTEGER",
            "number" => "NUMERIC",
            "string" => "TEXT",
            "boolean" => "BOOLEAN",
            _ => openApiType?.ToUpper() ?? "UNKNOWN"
        };
    }
}

class EntityInfo
{
    public string Name { get; set; }
    public List<ColumnInfo> Columns { get; set; }
    public List<RelationInfo> Relations { get; set; }
}

class ColumnInfo
{
    public string Name { get; set; }
    public string Type { get; set; }
    public bool IsRequired { get; set; }
}

class RelationInfo
{
    public string Type { get; set; }
    public string TargetEntity { get; set; }
    public string ForeignKey { get; set; }
}