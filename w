version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: tooljet_db
      POSTGRES_USER: tooljet_user
      POSTGRES_PASSWORD: tooljet_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tooljet_user -d tooljet_db"]
      interval: 5s
      timeout: 5s
      retries: 5
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  tooljet:
    image: tooljet/tooljet:latest
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - PG_HOST=postgres
      - PG_PORT=5432
      - PG_USER=tooljet_user
      - PG_PASS=tooljet_password
      - PG_DB_NAME=tooljet_db
      - TOOLJET_HOST=0.0.0.0
      - TOOLJET_PORT=3000
      - SECRET_KEY_BASE=your_generated_secret_key_here  # Замените на свой!
      - NODE_ENV=production
    ports:
      - "3000:3000"
    volumes:
      - tooljet_data:/app/storage

volumes:
  postgres_data:
  tooljet_data: