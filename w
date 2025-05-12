version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: tooljet_db
      POSTGRES_USER: tooljet_db_user
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
    command: redis-server --requirepass your_redis_password
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "your_redis_password", "ping"]
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
      # Database
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=tooljet_db_user
      - DB_PASSWORD=tooljet_db_password
      - DB_DATABASE=tooljet_db
      - DB_SSL=false

      # Redis
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=your_redis_password

      # App
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=3000
      - SECRET_KEY_BASE=your_secret_key_base
      - LOCKBOX_MASTER_KEY=your_lockbox_key
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