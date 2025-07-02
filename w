Вот подробная инструкция по миграции схемы и данных из MSSQL в PostgreSQL с помощью Entity Framework (C#/.NET):

## 1. Установите необходимые NuGet-пакеты

- **Npgsql.EntityFrameworkCore.PostgreSQL** — основной провайдер для PostgreSQL.
- **Microsoft.EntityFrameworkCore.Design** — для работы с миграциями.

Установите их через NuGet Package Manager или командой:
```bash
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.EntityFrameworkCore.Design
```


## 2. Получите модели из MSSQL (Reverse Engineering)

Если у вас нет C# моделей, сгенерируйте их из MSSQL с помощью команды:

```bash
dotnet ef dbcontext scaffold "Server=server;Database=dbname;User Id=user;Password=pass;" Microsoft.EntityFrameworkCore.SqlServer -o Models
```
- Эта команда создаст классы моделей и DbContext по вашей MSSQL базе[1].

## 3. Проверьте и адаптируйте модели

- Проверьте типы данных: некоторые типы MSSQL не имеют прямых аналогов в PostgreSQL, их нужно заменить вручную.
- Проверьте атрибуты и Fluent-конфигурации (например, специфичные для SQL Server аннотации и методы).
- Убедитесь, что все связи и ограничения отражены корректно.

## 4. Настройте DbContext для PostgreSQL

В вашем `DbContext` замените строку подключения и используйте Npgsql:

```csharp
protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
{
    optionsBuilder.UseNpgsql("Host=localhost;Port=5432;Database=dbname;Username=user;Password=pass");
}
```


## 5. Настройте строку подключения

- Лучше хранить строку подключения в переменных окружения или в `appsettings.json`.
- Пример для переменной окружения:
  ```bash
  setx PostgresConn "Host=localhost;Port=5432;Database=dbname;Username=user;Password=pass"
  ```
  В коде:
  ```csharp
  optionsBuilder.UseNpgsql(Environment.GetEnvironmentVariable("PostgresConn"));
  ```


## 6. Инициализируйте миграции

В терминале или Package Manager Console выполните:
```bash
dotnet ef migrations add InitialCreate
```
- Эта команда создаст миграцию, соответствующую вашей схеме моделей[2][3].

## 7. Примените миграции к PostgreSQL

```bash
dotnet ef database update
```
- Это создаст все таблицы, связи и ограничения в вашей PostgreSQL базе[2][3].

## 8. Перенос данных

- Для переноса данных используйте сторонние инструменты (например, DBConvert, pgloader) или напишите скрипты на C# для чтения из MSSQL и записи в PostgreSQL.
- Сам Entity Framework не мигрирует данные между разными СУБД, только схему.

## 9. Проверьте результат

- Проверьте структуру и целостность данных в PostgreSQL.
- Проверьте работу связей, ограничений, индексов.

## Важные замечания

- **Рекомендуется использовать Code First подход**: это позволяет гибко управлять схемой и миграциями при смене СУБД[4].
- Если проект был создан Database First, рекомендуется пересоздать модели под Code First.
- Обратите внимание на различия в поведении ограничений, типов данных и триггеров между MSSQL и PostgreSQL.

## Пример команд для миграции

```bash
# 1. Scaffold модели из MSSQL
dotnet ef dbcontext scaffold "Server=...;Database=...;User Id=...;Password=..." Microsoft.EntityFrameworkCore.SqlServer -o Models

# 2. Установите Npgsql и настройте DbContext

# 3. Добавьте первую миграцию
dotnet ef migrations add InitialCreate

# 4. Примените миграцию к PostgreSQL
dotnet ef database update
```


## Полезные ссылки

- [Официальная документация EF Core Migrations][2]
- [Пример настройки миграций для MSSQL и PostgreSQL в одном проекте][5]

**Этот подход позволяет перенести схему (структуру) базы данных, включая все таблицы и связи, с MSSQL на PostgreSQL средствами Entity Framework. Перенос данных выполняется отдельно.**

Источники
[1] Reverse Engineering Existing Databases with Entity Framework Core https://blog.jetbrains.com/dotnet/2023/07/20/reverse-engineering-existing-databases-with-entity-framework-core/
[2] EF Core Migrations: A Detailed Guide - Milan Jovanović https://www.milanjovanovic.tech/blog/efcore-migrations-a-detailed-guide
[3] Local PostgreSQL Database with Entity Framework Migrations https://scriptbytes.io/postgresql-database-entity-framework-migrations/
[4] Migrating from ef6 to postgresql in visual studio - Stack Overflow https://stackoverflow.com/questions/68878853/migrating-from-ef6-to-postgresql-in-visual-studio
[5] gokhansengun/Ef-Migrations-MsSql-Postgres - GitHub https://github.com/gokhansengun/Ef-Migrations-MsSql-Postgres
[6] Как мы сдружили EF 6 с MSSQL и PostgresSQL - Habr https://habr.com/ru/companies/crosstech/articles/445910/
[7] How to Convert SQL Server DB to Postgresql DB? : r/dotnet - Reddit https://www.reddit.com/r/dotnet/comments/1hknnti/how_to_convert_sql_server_db_to_postgresql_db/
[8] Connect to PostgreSQL Database with Entity Framework Core https://jasonwatmore.com/post/2022/06/23/net-6-connect-to-postgresql-database-with-entity-framework-core
[9] Entity Framework Database Schema Migrations: Types and Features https://www.apriorit.com/dev-blog/653-web-entity-framework-database-schema-migrations
[10] Converting Entity Framework MSSQL to PostgreSQL - Matt Kruskamp https://mattkruskamp.me/converting-entity-framework-mssql-to-postgres
