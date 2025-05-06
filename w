Ошибка `ECONNREFUSED 127.0.0.1:8000` указывает на проблему внутреннего соединения между компонентами Baserow. Вот как это исправить:

### Причина проблемы:
1. Frontend Baserow не может подключиться к backend (порт 8000)
2. Возможно, backend не запустился или работает неправильно
3. В конфигурации по умолчанию используется localhost, что внутри Docker не работает

### Решения:

1. **Обновлённый `docker-compose.yml`**:
```yaml
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U baserow -d baserow"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - baserow_network

  backend:
    image: baserow/baserow:latest
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://baserow:baserow@db:5432/baserow
      BASEROW_BACKEND_BIND_ADDRESS: 0.0.0.0
      BASEROW_BACKEND_PORT: 8000
    networks:
      - baserow_network
    volumes:
      - backend_data:/baserow/data

  frontend:
    image: baserow/baserow:latest
    depends_on:
      backend:
        condition: service_healthy
    environment:
      BASEROW_PUBLIC_URL: http://localhost
      BASEROW_BACKEND_URL: http://backend:8000
      BASEROW_WEBFRONTEND_BIND_ADDRESS: 0.0.0.0
      BASEROW_WEBFRONTEND_PORT: 3000
    ports:
      - "80:3000"
    networks:
      - baserow_network

volumes:
  postgres_data:
  backend_data:

networks:
  baserow_network:
    driver: bridge
```

### Ключевые изменения:
1. Разделил сервисы на `backend` и `frontend`
2. Явно указал адреса и порты для внутренней коммуникации
3. Заменил localhost на имя сервиса `backend` для внутренних соединений

### Дополнительные шаги:
1. Удалите старые контейнеры и volumes:
```bash
docker-compose down -v
```

2. Пересоздайте сервисы:
```bash
docker-compose up -d
```

3. Проверьте логи каждого компонента:
```bash
docker-compose logs backend
docker-compose logs frontend
docker-compose logs db
```

### Если проблема сохраняется:
1. Увеличьте таймауты:
```yaml
environment:
  BASEROW_STARTUP_TIMEOUT: "300"  # 5 минут вместо стандартных 60 секунд
```

2. Проверьте доступность backend:
```bash
docker-compose exec backend curl -v http://localhost:8000/api/health/
```

3. Для production используйте официальные образы с тегами версий вместо `latest`

После этих изменений frontend должен корректно подключаться к backend через Docker network. Ошибка ECONNREFUSED больше не должна появляться.