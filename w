Вот готовый `docker-compose.yml` для быстрого запуска **Metabase** вместе с **PostgreSQL** (если у вас уже есть своя БД, можно убрать сервис `postgres`):

```yaml
version: '3.8'

services:
  # Основной сервис Metabase
  metabase:
    image: metabase/metabase:latest
    container_name: metabase
    ports:
      - "3000:3000"  # Web-интерфейс будет доступен на http://localhost:3000
    environment:
      MB_DB_TYPE: postgres
      MB_DB_DBNAME: metabase
      MB_DB_PORT: 5432
      MB_DB_USER: metabase
      MB_DB_PASS: metabase
      MB_DB_HOST: postgres
    depends_on:
      - postgres
    networks:
      - metanet
    restart: unless-stopped

  # PostgreSQL для хранения данных Metabase (если не используете внешнюю БД)
  postgres:
    image: postgres:13
    container_name: postgres
    environment:
      POSTGRES_USER: metabase
      POSTGRES_PASSWORD: metabase
      POSTGRES_DB: metabase
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - metanet
    restart: unless-stopped

# Сеть и volume для хранения данных
networks:
  metanet:
    driver: bridge

volumes:
  postgres_data:
```

### **Как использовать:**
1. Сохраните этот код в файл `docker-compose.yml`.
2. Запустите командой:
   ```bash
   docker-compose up -d
   ```
3. Откройте в браузере: [http://localhost:3000](http://localhost:3000).
4. При первом запуске:
   - Создайте админ-аккаунт.
   - Подключите свою **PostgreSQL БД с данными из Dynamics CRM** (если не используете встроенную `postgres` из этого файла).

### **Если у вас уже есть PostgreSQL с данными:**
1. Удалите сервис `postgres` из `docker-compose.yml`.
2. В сервисе `metabase` измените переменные окружения:
   ```yaml
   environment:
     MB_DB_TYPE: postgres
     MB_DB_DBNAME: your_database_name
     MB_DB_PORT: 5432
     MB_DB_USER: your_username
     MB_DB_PASS: your_password
     MB_DB_HOST: your_postgres_host  # Например, IP или домен БД
   ```

### **Дополнительно:**
- Если Metabase нужно подключить к **существующей БД**, укажите её параметры вместо `postgres` в `environment`.
- Для продакшена настройте **TLS (HTTPS)** и бэкапы.

После запуска вы сможете:
- Назначать "человеческие" названия таблицам и полям.
- Строить дашборды с фильтрами.
- Настраивать связи между таблицами для навигации.