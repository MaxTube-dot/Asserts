Добавим инициализацию PostgreSQL с помощью SQL-скрипта. Вот обновлённый `docker-compose.yml`:

```yaml
version: '3.8'

services:
  db:
    image: postgres:13
    environment:
      POSTGRES_DB: baserow
      POSTGRES_USER: baserow
      POSTGRES_PASSWORD: baserow
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped
    networks:
      - baserow_network

  baserow:
    image: baserow/baserow:latest
    depends_on:
      db:
        condition: service_healthy
    environment:
      BASEROW_PUBLIC_URL: http://localhost:80
      DATABASE_URL: postgres://baserow:baserow@db:5432/baserow
    ports:
      - "80:80"
    volumes:
      - baserow_data:/baserow/data
    restart: unless-stopped
    networks:
      - baserow_network

volumes:
  postgres_data:
  baserow_data:

networks:
  baserow_network:
    driver: bridge

healthcheck:
  db:
    test: ["CMD-SHELL", "pg_isready -U baserow -d baserow"]
    interval: 5s
    timeout: 5s
    retries: 5
```

### Что изменилось:
1. Добавлен healthcheck для PostgreSQL, чтобы Baserow запускался только после готовности БД
2. Добавлено монтирование SQL-скрипта в `/docker-entrypoint-initdb.d/`

### Как добавить SQL-скрипт:
1. Создайте файл `init.sql` в той же директории, где находится `docker-compose.yml`
2. Добавьте в него нужные SQL-команды, например:

```sql
-- Пример init.sql
CREATE SCHEMA IF NOT EXISTS baserow_schema;

-- Создание дополнительных таблиц (если нужно)
CREATE TABLE IF NOT EXISTS baserow_schema.example_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Можно добавить начальные данные
INSERT INTO baserow_schema.example_table (name) VALUES ('Initial Data');
```

### Важные моменты:
1. Файл `init.sql` выполняется только при первом запуске контейнера с пустым volume
2. Для повторного выполнения скрипта нужно:
   - Удалить volume: `docker-compose down -v`
   - Запустить заново: `docker-compose up -d`
3. Baserow сам создаёт нужные ему таблицы, поэтому обычно в `init.sql` добавляют только кастомные объекты БД

Хотите, чтобы я добавил что-то конкретное в SQL-скрипт или изменил логику инициализации?