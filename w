# Подробный альтернативный вариант переноса структуры через SQLAlchemy

SQLAlchemy предоставляет мощный инструментарий для работы с метаданными базы данных, что делает его идеальным выбором для переноса структуры между различными СУБД. Рассмотрим этот подход детально.

## 1. Настройка окружения

### Установка необходимых пакетов
```bash
pip install sqlalchemy pyodbc psycopg2 sqlalchemy-utils
```

## 2. Полный скрипт для генерации DDL

```python
from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy.schema import CreateTable, CreateIndex
from sqlalchemy.dialects import postgresql
import re

def clean_identifier(name):
    """Очистка идентификаторов от специальных символов"""
    return re.sub(r'[^a-zA-Z0-9_]', '_', name)

def convert_mssql_to_pg_ddl(mssql_connection_string, output_file):
    """Генерация PostgreSQL DDL из структуры MS SQL"""
    
    # Создаем подключение к MS SQL
    mssql_engine = create_engine(mssql_connection_string)
    mssql_metadata = MetaData()
    
    # Получаем все таблицы, включая индексы и ограничения
    mssql_metadata.reflect(bind=mssql_engine)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        # Сначала создаем таблицы без внешних ключей
        tables_without_fk = []
        tables_with_fk = []
        
        for table in mssql_metadata.sorted_tables:
            if table.foreign_keys:
                tables_with_fk.append(table)
            else:
                tables_without_fk.append(table)
        
        # Записываем CREATE TABLE для таблиц без внешних ключей
        for table in tables_without_fk:
            pg_ddl = str(CreateTable(table).compile(dialect=postgresql.dialect())
            f.write(f"-- Table: {table.name}\n")
            f.write(f"{pg_ddl};\n\n")
        
        # Затем таблицы с внешними ключами
        for table in tables_with_fk:
            # Создаем таблицу без ограничений
            temp_table = Table(
                table.name,
                table.metadata,
                *[col.copy() for col in table.columns],
                schema=table.schema
            )
            
            pg_ddl = str(CreateTable(temp_table).compile(dialect=postgresql.dialect()))
            f.write(f"-- Table: {table.name}\n")
            f.write(f"{pg_ddl};\n\n")
        
        # Добавляем первичные ключи
        for table in mssql_metadata.sorted_tables:
            if table.primary_key:
                pk_columns = [col.name for col in table.primary_key.columns]
                f.write(f"-- Primary key for {table.name}\n")
                f.write(f"ALTER TABLE {table.name} ADD CONSTRAINT pk_{table.name} ")
                f.write(f"PRIMARY KEY ({', '.join(pk_columns)});\n\n")
        
        # Добавляем индексы
        for table in mssql_metadata.sorted_tables:
            for index in table.indexes:
                if not index.unique:  # UNIQUE обрабатываются как ограничения
                    idx_columns = [col.name for col in index.columns]
                    f.write(f"-- Index: {index.name}\n")
                    f.write(f"CREATE INDEX {index.name} ON {table.name} ")
                    f.write(f"({', '.join(idx_columns)});\n\n")
        
        # Добавляем внешние ключи
        for table in tables_with_fk:
            for fk in table.foreign_keys:
                f.write(f"-- Foreign key: {fk.name}\n")
                f.write(f"ALTER TABLE {table.name} ADD CONSTRAINT {fk.name} ")
                f.write(f"FOREIGN KEY ({fk.parent.name}) ")
                f.write(f"REFERENCES {fk.column.table.name} ({fk.column.name})")
                
                # Обработка ON DELETE/ON UPDATE
                if fk.ondelete:
                    f.write(f" ON DELETE {fk.ondelete.upper()}")
                if fk.onupdate:
                    f.write(f" ON UPDATE {fk.onupdate.upper()}")
                
                f.write(";\n\n")
        
        # Добавляем уникальные ограничения
        for table in mssql_metadata.sorted_tables:
            for index in table.indexes:
                if index.unique and not index.primary_key:
                    unique_cols = [col.name for col in index.columns]
                    f.write(f"-- Unique constraint: {index.name}\n")
                    f.write(f"ALTER TABLE {table.name} ADD CONSTRAINT {index.name} ")
                    f.write(f"UNIQUE ({', '.join(unique_cols)});\n\n")

if __name__ == "__main__":
    # Параметры подключения к MS SQL
    mssql_conn_str = (
        "mssql+pyodbc://username:password@server/database?"
        "driver=ODBC+Driver+17+for+SQL+Server"
    )
    
    # Файл для вывода PostgreSQL DDL
    output_file = "postgres_schema.sql"
    
    convert_mssql_to_pg_ddl(mssql_conn_str, output_file)
    print(f"PostgreSQL DDL успешно сгенерирован в файл {output_file}")
```

## 3. Особенности реализации

### Обработка типов данных
Скрипт автоматически преобразует типы данных через SQLAlchemy:
- `NVARCHAR` → `VARCHAR`
- `DATETIME` → `TIMESTAMP`
- `BIT` → `BOOLEAN`
- `UNIQUEIDENTIFIER` → `UUID`

### Сохранение связей
Алгоритм гарантирует правильный порядок создания таблиц:
1. Сначала независимые таблицы (без внешних ключей)
2. Затем зависимые таблицы
3. В конце добавляются все ограничения внешних ключей

### Поддержка схем
Скрипт сохраняет оригинальные имена схем. Если нужно перенести все в схему `public`:
```python
# В функции convert_mssql_to_pg_ddl замените:
temp_table = Table(
    table.name,
    table.metadata,
    *[col.copy() for col in table.columns],
    schema='public'  # вместо table.schema
)
```

## 4. Перенос между изолированными сетями

1. **На стороне MS SQL**:
   - Запустите скрипт для генерации `postgres_schema.sql`
   - Упакуйте файл: `zip schema.zip postgres_schema.sql`

2. **Перенос файла**:
   - Используйте утвержденный метод (SFTP, USB и т.д.)

3. **На стороне PostgreSQL**:
   - Распакуйте архив
   - Выполните: `psql -U username -d dbname -f postgres_schema.sql`

## 5. Дополнительные улучшения

### Логирование и проверки
```python
def validate_schema(mssql_metadata, pg_engine):
    """Сравнение структуры исходной и целевой БД"""
    pg_metadata = MetaData()
    pg_metadata.reflect(bind=pg_engine)
    
    mssql_tables = {t.name: t for t in mssql_metadata.sorted_tables}
    pg_tables = {t.name: t for t in pg_metadata.sorted_tables}
    
    for name, mssql_table in mssql_tables.items():
        if name not in pg_tables:
            print(f"Таблица {name} отсутствует в PostgreSQL")
            continue
            
        pg_table = pg_tables[name]
        # Проверка столбцов
        for mssql_col in mssql_table.columns:
            pg_col = pg_table.columns.get(mssql_col.name)
            if not pg_col:
                print(f"Столбец {mssql_col.name} отсутствует в таблице {name}")
```

### Поддержка специфических конструкций
Для обработки особых случаев (например, вычисляемых столбцов) добавьте кастомную логику:
```python
for column in table.columns:
    if column.computed:
        # Обработка вычисляемых столбцов
        pg_expr = convert_mssql_expression_to_pg(column.server_default.arg.text)
        f.write(f"ALTER TABLE {table.name} ADD COLUMN {column.name} ")
        f.write(f"GENERATED ALWAYS AS ({pg_expr}) STORED;\n")
```

## 6. Ограничения и обходные пути

1. **Триггеры и хранимые процедуры**:
   - Не переносятся автоматически, требуется ручная миграция
   - Для переноса добавьте анализ `sys.sql_modules`

2. **Специфические типы данных**:
   - Пользовательские типы требуют ручного преобразования
   - Решение: добавить маппинг в `convert_mssql_to_pg_ddl`

3. **Партиционирование**:
   - Не поддерживается автоматическим отражением
   - Решение: ручное добавление после базовой миграции

Этот подход обеспечивает максимально точный перенос структуры базы данных с сохранением всех связей и ограничений, даже между изолированными средами.