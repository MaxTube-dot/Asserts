version: '3.8'

services:
  # PostgreSQL database
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - db-network
    restart: unless-stopped

  # pgAdmin - GUI for PostgreSQL
  pgadmin:
    image: dpage/pgadmin4
    container_name: pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: secret
    ports:
      - "5050:80"
    networks:
      - db-network
    depends_on:
      - postgres
    restart: unless-stopped

  # PostgREST - REST API for PostgreSQL
  postgrest:
    image: postgrest/postgrest
    container_name: postgrest
    environment:
      PGRST_DB_URI: "postgres://admin:secret@postgres:5432/mydb"
      PGRST_DB_SCHEMA: "public"
      PGRST_DB_ANON_ROLE: "admin"
      PGRST_DB_CONFIG: "true"
      PGRST_OPENAPI_SERVER_PROXY_URI: "http://localhost:3000"
    ports:
      - "3000:3000"
    networks:
      - db-network
    depends_on:
      - postgres
    restart: unless-stopped

  # Swagger UI for PostgREST
  swagger:
    image: swaggerapi/swagger-ui
    container_name: swagger
    ports:
      - "8080:8080"
    environment:
      API_URL: "http://postgrest:3000/"
    networks:
      - db-network
    depends_on:
      - postgres
      - postgrest
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  db-network:
    driver: bridge