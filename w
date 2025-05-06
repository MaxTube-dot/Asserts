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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U baserow -d baserow"]
      interval: 5s
      timeout: 5s
      retries: 5

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