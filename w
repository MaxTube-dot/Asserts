version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - db-network
    restart: unless-stopped

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

  postgrest:
    image: postgrest/postgrest
    container_name: postgrest
    environment:
      PGRST_DB_URI: "postgres://admin:secret@postgres:5432/mydb"
      PGRST_DB_SCHEMA: "public"
      PGRST_DB_ANON_ROLE: "admin"
      PGRST_JWT_SECRET: "reallyreallyreallyreallyverysafe"
      PGRST_SERVER_PROXY_URI: "http://localhost:3000"
      PGRST_OPENAPI_SERVER_PROXY_URI: "http://localhost:3000"
      PGRST_CORS_ALLOWED_ORIGINS: "*"
      PGRST_CORS_MAX_AGE: "300"
    ports:
      - "3000:3000"
    networks:
      - db-network
    depends_on:
      - postgres
    restart: unless-stopped

  swagger:
    image: swaggerapi/swagger-ui
    container_name: swagger
    ports:
      - "8080:8080"
    environment:
      URL: "http://localhost:3000/openapi.json"
      VALIDATOR_URL: "none"
    networks:
      - db-network
    depends_on:
      - postgrest
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  db-network:
    driver: bridge