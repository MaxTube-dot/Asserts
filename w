version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: tooljet_db
      POSTGRES_USER: tooljet_db_user  # Именно такое имя ожидает ToolJet
      POSTGRES_PASSWORD: tooljet_db_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tooljet_db_user -d tooljet_db"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine
    command: redis-server --requirepass redis_password
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redis_password", "ping"]
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
      # Обязательные параметры БД (новые названия!)
      - TOOLJET_DB_HOST=postgres
      - TOOLJET_DB_PORT=5432
      - TOOLJET_DB_USER=tooljet_db_user  # Должен совпадать с POSTGRES_USER
      - TOOLJET_DB_PASSWORD=tooljet_db_password
      - TOOLJET_DB_NAME=tooljet_db
      - TOOLJET_DB_SSL=false

      # Redis (новый формат)
      - TOOLJET_REDIS_HOST=redis
      - TOOLJET_REDIS_PORT=6379
      - TOOLJET_REDIS_PASSWORD=redis_password

      # Системные настройки
      - TOOLJET_HOST=0.0.0.0
      - TOOLJET_PORT=3000
      - SECRET_KEY_BASE=your_secure_key_here  # openssl rand -hex 64
      - LOCKBOX_MASTER_KEY=your_lockbox_key  # openssl rand -hex 32
      - NODE_ENV=production
    ports:
      - "3000:3000"
    volumes:
      - tooljet_data:/app/storage
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  tooljet_data: