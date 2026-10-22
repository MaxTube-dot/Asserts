services:
  pg-primary:
    image: bitnami/postgresql:17
    container_name: pg-primary
    environment:
      # Настройки репликации
      - POSTGRESQL_REPLICATION_MODE=master
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      # Основные данные для подключения
      - POSTGRESQL_USERNAME=app_user
      - POSTGRESQL_PASSWORD=app_password
      - POSTGRESQL_DATABASE=app_db
    ports:
      - "5432:5432"
    volumes:
      - pg_primary_data:/bitnami/postgresql
    networks:
      - pg_network
    restart: unless-stopped

  pg-replica:
    image: bitnami/postgresql:17
    container_name: pg-replica
    environment:
      # Настройки реплики
      - POSTGRESQL_REPLICATION_MODE=slave
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      - POSTGRESQL_MASTER_HOST=pg-primary
      - POSTGRESQL_MASTER_PORT_NUMBER=5432
    ports:
      - "5433:5432" # Реплика будет доступна на порту 5433 хоста
    depends_on:
      - pg-primary
    volumes:
      - pg_replica_data:/bitnami/postgresql
    networks:
      - pg_network
    restart: unless-stopped

volumes:
  pg_primary_data:
  pg_replica_data:

networks:
  pg_network:
    driver: bridge
