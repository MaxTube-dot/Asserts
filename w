version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: tooljet_db
      POSTGRES_USER: tooljet_user
      POSTGRES_PASSWORD: tooljet_password  # На продакшне замените на сложный пароль!
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tooljet_user -d tooljet_db"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine  # Используем облегчённый alpine-образ
    command: redis-server --requirepass redis_password  # Пароль для Redis
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redis_password", "ping"]  # Проверка с паролем
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - redis_data:/data

  tooljet:
    image: tooljet/tooljet:latest
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      # Настройки PostgreSQL
      - PG_HOST=postgres
      - PG_PORT=5432
      - PG_USER=tooljet_user
      - PG_PASS=tooljet_password
      - PG_DB_NAME=tooljet_db

      # Настройки Redis (исправлено!)
      - REDIS_URL=redis://:redis_password@redis:6379  # Формат URL для подключения
      
      # Настройки ToolJet
      - TOOLJET_HOST=0.0.0.0
      - TOOLJET_PORT=3000
      - SECRET_KEY_BASE=your_secure_key_here  # Обязательно замените!
      - NODE_ENV=production
      - LOCKBOX_MASTER_KEY=your_lockbox_key_here  # Добавлено для безопасности
    ports:
      - "3000:3000"
    volumes:
      - tooljet_data:/app/storage
    restart: unless-stopped  # Автоперезапуск при падении

volumes:
  postgres_data:
  redis_data:
  tooljet_data: