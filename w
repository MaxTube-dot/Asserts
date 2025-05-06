Отличный выбор! Вот готовый `docker-compose.yml` для кастомного решения с **PostgreSQL + Hasura (GraphQL API) + AdminJS** (админ-панель):

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin
      POSTGRES_DB: appdb
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - app_network

  hasura:
    image: hasura/graphql-engine:v2.33.0
    container_name: hasura
    depends_on:
      - postgres
    environment:
      HASURA_GRAPHQL_DATABASE_URL: "postgres://admin:admin@postgres:5432/appdb"
      HASURA_GRAPHQL_ENABLE_CONSOLE: "true"
      HASURA_GRAPHQL_ADMIN_SECRET: "myadminsecretkey"
      HASURA_GRAPHQL_DEV_MODE: "false"
    ports:
      - "8080:8080"  # Hasura Console
    networks:
      - app_network

  adminjs:
    image: node:18
    container_name: adminjs
    depends_on:
      - postgres
      - hasura
    working_dir: /app
    volumes:
      - ./adminjs:/app
    environment:
      NODE_ENV: production
      DATABASE_URL: "postgres://admin:admin@postgres:5432/appdb"
      HASURA_GRAPHQL_URL: "http://hasura:8080/v1/graphql"
    ports:
      - "3000:3000"  # AdminJS панель
    networks:
      - app_network
    command: >
      sh -c "npm install && npm start"

volumes:
  postgres_data:

networks:
  app_network:
    driver: bridge
```

---

## **Как это работает?**
1. **PostgreSQL**:
   - Основная БД (`appdb`).
   - SQL-скрипт `init.sql` создаст таблицы при старте (пример ниже).

2. **Hasura**:
   - Автоматически генерирует GraphQL API для PostgreSQL.
   - Консоль доступна на `http://localhost:8080`.

3. **AdminJS**:
   - Админ-панель с UI для управления данными.
   - Доступна на `http://localhost:3000`.

---

## **Шаги для запуска**
### 1. Создайте файл `init.sql` (структура БД)
```sql
-- Клиенты
CREATE TABLE client (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Товары
CREATE TABLE product (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  price DECIMAL(10, 2) NOT NULL
);

-- Заказы (связи с клиентами и товарами)
CREATE TABLE "order" (
  id SERIAL PRIMARY KEY,
  client_id INTEGER REFERENCES client(id),
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Товары в заказе (N:M)
CREATE TABLE order_item (
  order_id INTEGER REFERENCES "order"(id),
  product_id INTEGER REFERENCES product(id),
  quantity INTEGER NOT NULL,
  PRIMARY KEY (order_id, product_id)
);
```

### 2. Создайте папку `adminjs` с файлами:
#### `package.json`
```json
{
  "name": "adminjs-app",
  "version": "1.0.0",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "@adminjs/express": "^5.0.0",
    "@adminjs/postgres": "^2.0.0",
    "@adminjs/hasura": "^1.0.0",
    "adminjs": "^6.0.0",
    "express": "^4.18.2",
    "pg": "^8.11.0"
  }
}
```

#### `app.js`
```javascript
const AdminJS = require('adminjs');
const AdminJSExpress = require('@adminjs/express');
const AdminJSPostgres = require('@adminjs/postgres');
const AdminJSHasura = require('@adminjs/hasura');

// Подключение к PostgreSQL
AdminJS.registerAdapter({
  Database: AdminJSPostgres.Database,
  Resource: AdminJSPostgres.Resource,
});

const adminJs = new AdminJS({
  databases: [], // Автоматическое определение таблиц из PostgreSQL
  rootPath: '/admin',
  branding: {
    companyName: 'My Custom CRM',
  },
});

const router = AdminJSExpress.buildRouter(adminJs);

const app = require('express')();
app.use(adminJs.options.rootPath, router);

app.listen(3000, () => {
  console.log('AdminJS доступен на http://localhost:3000/admin');
});
```

### 3. Запустите систему:
```bash
docker-compose up -d
```

---

## **Что вы получите?**
1. **Hasura GraphQL API**:
   - Доступен на `http://localhost:8080`.
   - Запросы к данным через GraphQL:
     ```graphql
     query {
       clients {
         id
         name
         orders { status products { name } }
       }
     }
     ```

2. **AdminJS Панель**:
   - Доступна на `http://localhost:3000/admin`.
   - Возможности:
     - Управление таблицами (CRUD).
     - Фильтрация и сортировка.
     - Экспорт данных (CSV/JSON).
     - Настройка прав доступа.

3. **PostgreSQL**:
   - Данные сохраняются в Docker-томе (`postgres_data`).

---

## **Дополнительные настройки**
### Для Hasura:
- Настройте права доступа в консоли (`http://localhost:8080` → `Data` → `Permissions`).
- Добавьте аутентификацию через JWT, если нужно.

### Для AdminJS:
- Кастомизируйте интерфейс в `app.js`:
  ```javascript
  const adminJs = new AdminJS({
    resources: [{
      resource: { model: 'Client', client: 'postgres' },
      options: { properties: { password: { isVisible: false } } }
    }]
  });
  ```

Это решение даст вам **полный контроль** над данными и интерфейсом без ограничений no-code инструментов.