version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: tooljet
      POSTGRES_USER: tooljet
      POSTGRES_PASSWORD: tooljet
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tooljet -d tooljet"]
      interval: 5s
      timeout: 5s
      retries: 5

  tooljet:
    image: tooljet/tooljet:latest
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - TOOLJET_DB=postgres
      - TOOLJET_DB_HOST=postgres
      - TOOLJET_DB_PORT=5432
      - TOOLJET_DB_USER=tooljet
      - TOOLJET_DB_PASS=tooljet
      - TOOLJET_DB_NAME=tooljet
      - TOOLJET_SERVER_URL=http://localhost:3000
      - NODE_ENV=production
      - SECRET_KEY_BASE=your-secret-key-base-here
    ports:
      - "3000:3000"
    volumes:
      - tooljet_data:/app/storage

volumes:
  postgres_data:
  tooljet_data: