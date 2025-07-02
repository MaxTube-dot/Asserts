# Перенос структуры таблиц, связей и индексов из MS SQL в PostgreSQL

Для переноса только структуры таблиц (без данных) с сохранением связей и индексов между изолированными подсетями предлагаю следующий метод:

## 1. Генерация DDL из MS SQL

### Получение метаданных о таблицах, связях и индексах

```sql
-- Полный скрипт для генерации DDL с индексами и связями
WITH tables AS (
    SELECT 
        t.object_id,
        SCHEMA_NAME(t.schema_id) AS schema_name,
        t.name AS table_name,
        (SELECT STRING_AGG(
            QUOTENAME(c.name) + ' ' + 
            CASE 
                WHEN tp.name IN ('varchar', 'nvarchar', 'char', 'nchar') THEN 
                    UPPER(REPLACE(tp.name, 'n', '')) + 
                    CASE WHEN c.max_length = -1 THEN '(MAX)' 
                         ELSE '(' + CAST(c.max_length AS VARCHAR) + ')' END
                WHEN tp.name IN ('decimal', 'numeric') THEN 
                    'NUMERIC(' + CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')'
                WHEN tp.name = 'datetime2' THEN 'TIMESTAMP'
                WHEN tp.name = 'datetime' THEN 'TIMESTAMP'
                WHEN tp.name = 'smalldatetime' THEN 'TIMESTAMP'
                WHEN tp.name = 'bit' THEN 'BOOLEAN'
                WHEN tp.name = 'uniqueidentifier' THEN 'UUID'
                WHEN tp.name = 'image' THEN 'BYTEA'
                WHEN tp.name IN ('binary', 'varbinary') THEN 'BYTEA'
                WHEN tp.name = 'float' THEN 'DOUBLE PRECISION'
                WHEN tp.name = 'real' THEN 'REAL'
                WHEN tp.name = 'money' THEN 'MONEY'
                WHEN tp.name = 'smallmoney' THEN 'MONEY'
                WHEN tp.name LIKE '%int%' THEN UPPER(tp.name)
                ELSE UPPER(tp.name)
            END + ' ' +
            CASE WHEN c.is_nullable = 0 THEN 'NOT NULL' ELSE '' END + ' ' +
            CASE WHEN ic.column_id IS NOT NULL AND i.is_primary_key = 1 THEN 'PRIMARY KEY' ELSE '' END + ' ' +
            CASE WHEN c.is_identity = 1 THEN 
                CASE WHEN IDENT_SEED(SCHEMA_NAME(t.schema_id) + '.' + t.name) IS NOT NULL 
                     THEN 'GENERATED ALWAYS AS IDENTITY' 
                     ELSE '' END
                ELSE '' END,
            ', ' + CHAR(13) + CHAR(10)
        FROM sys.columns c
        JOIN sys.types tp ON c.user_type_id = tp.user_type_id
        LEFT JOIN sys.indexes i ON t.object_id = i.object_id AND i.is_primary_key = 1
        LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id 
                                      AND c.column_id = ic.column_id
        WHERE c.object_id = t.object_id
        ) AS columns_ddl
    FROM sys.tables t
)
SELECT 
    '-- Table: ' + schema_name + '.' + table_name + CHAR(13) + CHAR(10) +
    'CREATE TABLE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ' (' + CHAR(13) + CHAR(10) +
    '    ' + columns_ddl + CHAR(13) + CHAR(10) +
    ');' + CHAR(13) + CHAR(10) +
    
    -- Добавляем индексы (кроме первичных ключей)
    ISNULL((
        SELECT CHAR(13) + CHAR(10) + '-- Indexes for table: ' + schema_name + '.' + table_name + CHAR(13) + CHAR(10) +
        STRING_AGG(
            'CREATE ' + 
            CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END +
            'INDEX ' + QUOTENAME(i.name) + ' ON ' + 
            QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) + ' (' +
            STRING_AGG(QUOTENAME(c.name) + 
            CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END, ', ') +
            ');',
            CHAR(13) + CHAR(10)
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.object_id = t.object_id
          AND i.is_primary_key = 0
          AND i.type = 2 -- B-tree indexes
        GROUP BY i.name, i.is_unique
    ), '') +
    
    -- Добавляем внешние ключи
    ISNULL((
        SELECT CHAR(13) + CHAR(10) + '-- Foreign keys for table: ' + schema_name + '.' + table_name + CHAR(13) + CHAR(10) +
        STRING_AGG(
            'ALTER TABLE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + 
            ' ADD CONSTRAINT ' + QUOTENAME(fk.name) + 
            ' FOREIGN KEY (' + STRING_AGG(QUOTENAME(pc.name), ', ') + ')' +
            ' REFERENCES ' + QUOTENAME(SCHEMA_NAME(ro.schema_id)) + '.' + QUOTENAME(ro.name) + 
            ' (' + STRING_AGG(QUOTENAME(rc.name), ', ') + ')' +
            CASE WHEN fk.delete_referential_action = 1 THEN ' ON DELETE CASCADE'
                 WHEN fk.delete_referential_action = 2 THEN ' ON DELETE SET NULL'
                 WHEN fk.delete_referential_action = 3 THEN ' ON DELETE SET DEFAULT'
                 ELSE '' END +
            CASE WHEN fk.update_referential_action = 1 THEN ' ON UPDATE CASCADE'
                 WHEN fk.update_referential_action = 2 THEN ' ON UPDATE SET NULL'
                 WHEN fk.update_referential_action = 3 THEN ' ON UPDATE SET DEFAULT'
                 ELSE '' END + ';',
            CHAR(13) + CHAR(10))
        FROM sys.foreign_keys fk
        JOIN sys.tables ro ON fk.referenced_object_id = ro.object_id
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
        JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
        WHERE fk.parent_object_id = t.object_id
        GROUP BY fk.name, ro.name, ro.schema_id, 
                 fk.delete_referential_action, fk.update_referential_action
    ), '') AS full_ddl
FROM sys.tables t
JOIN tables ON t.object_id = tables.object_id
ORDER BY CASE WHEN EXISTS (
    SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id = t.object_id
) THEN 0 ELSE 1 END, t.name;
```

## 2. Преобразование DDL для PostgreSQL

После получения DDL из MS SQL нужно выполнить следующие преобразования:

1. **Типы данных**:
   - `NVARCHAR` → `VARCHAR`
   - `DATETIME` → `TIMESTAMP`
   - `BIT` → `BOOLEAN`
   - `UNIQUEIDENTIFIER` → `UUID`
   - `IDENTITY` → `GENERATED ALWAYS AS IDENTITY`

2. **Синтаксис ограничений**:
   - `[PRIMARY] CLUSTERED` → удалить (PostgreSQL не использует это понятие)
   - `WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF...)` → удалить

3. **Схемы**:
   - Убедитесь, что схемы существуют в PostgreSQL или замените на `public`

## 3. Оптимизированный подход для изолированных сетей

1. **Генерация скриптов на стороне MS SQL**:
   ```powershell
   # PowerShell скрипт для генерации DDL
   $query = "SELECT ..." # Запрос из предыдущего раздела
   $outputFile = "C:\export\postgres_ddl.sql"
   
   Invoke-Sqlcmd -ServerInstance "your_server" -Database "your_db" -Query $query | 
   Out-File -FilePath $outputFile -Encoding UTF8
   ```

2. **Перенос файла**:
   - Упакуйте SQL-файл в архив
   - Передайте через утвержденный канал (SFTP, USB и т.д.)

3. **Применение в PostgreSQL**:
   ```bash
   psql -U username -d dbname -f /path/to/postgres_ddl.sql
   ```

## 4. Проверка целостности после переноса

```sql
-- Проверка таблиц
SELECT table_name, 
       (SELECT COUNT(*) FROM information_schema.columns 
        WHERE table_name = t.table_name) AS columns_count
FROM information_schema.tables t
WHERE table_schema = 'public'
ORDER BY table_name;

-- Проверка индексов
SELECT tablename, indexname, indexdef 
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Проверка внешних ключей
SELECT conname AS constraint_name,
       conrelid::regclass AS table_name,
       pg_get_constraintdef(oid) AS constraint_def
FROM pg_constraint
WHERE contype = 'f' AND connamespace = 'public'::regnamespace
ORDER BY conrelid::regclass::text;
```

## Альтернативный вариант: использование SQLAlchemy для генерации метаданных

Если у вас есть доступ к Python в обеих средах:

```python
from sqlalchemy import create_engine, MetaData

# Генерация метаданных из MS SQL
mssql_engine = create_engine('mssql+pyodbc://...')
mssql_metadata = MetaData()
mssql_metadata.reflect(bind=mssql_engine)

# Генерация PostgreSQL DDL
pg_ddl = []
for table in mssql_metadata.sorted_tables:
    # Преобразование типов и синтаксиса
    pg_ddl.append(str(table.compile(dialect=postgresql.dialect())) 

# Сохранение в файл
with open('schema_postgres.sql', 'w') as f:
    f.write('\n'.join(pg_ddl))
```

Этот подход позволяет перенести всю структуру базы данных, включая сложные связи и индексы, без необходимости прямого соединения между серверами.