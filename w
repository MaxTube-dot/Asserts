Вы правы — в предыдущем примере были указаны несуществующие пакеты (особенно `@adminjs/hasura`). Давайте исправим конфигурацию **AdminJS** для работы с **PostgreSQL** без лишних зависимостей. Вот актуальное решение:

---

### **Исправленный `docker-compose.yml`**
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
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
    depends_on:
      - postgres
    environment:
      HASURA_GRAPHQL_DATABASE_URL: "postgres://admin:admin@postgres:5432/appdb"
      HASURA_GRAPHQL_ENABLE_CONSOLE: "true"
      HASURA_GRAPHQL_ADMIN_SECRET: "myadminsecretkey"
    ports:
      - "8080:8080"
    networks:
      - app_network

  adminjs:
    build: ./adminjs  # Собираем образ из папки adminjs
    depends_on:
      - postgres
    environment:
      DATABASE_URL: "postgres://admin:admin@postgres:5432/appdb"
    ports:
      - "3000:3000"
    networks:
      - app_network

volumes:
  postgres_data:

networks:
  app_network:
    driver: bridge
```

---

### **Исправленные файлы для AdminJS**
#### 1. Создайте папку `adminjs` и файлы:

##### `adminjs/Dockerfile`
```dockerfile
FROM node:18

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
CMD ["npm", "start"]
```

##### `adminjs/package.json`
```json
{
  "name": "adminjs-app",
  "version": "1.0.0",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "adminjs": "^6.8.0",
    "@adminjs/express": "^5.0.0",
    "@adminjs/typeorm": "^2.0.0",
    "express": "^4.18.2",
    "typeorm": "^0.3.17",
    "pg": "^8.11.0"
  }
}
```

##### `adminjs/app.js`
```javascript
const AdminJS = require('adminjs');
const AdminJSExpress = require('@adminjs/express');
const { Database, Resource } = require('@adminjs/typeorm');
const { getConnection } = require('typeorm');
const express = require('express');

// Регистрируем адаптер TypeORM для AdminJS
AdminJS.registerAdapter({ Database, Resource });

// Инициализация AdminJS
const startAdminJS = async () => {
  const connection = await getConnection();
  const adminJs = new AdminJS({
    databases: [connection],
    rootPath: '/admin',
    resources: [
      {
        resource: connection.getMetadata('client').target, // Автоматическое определение сущностей
        options: { properties: { password: { isVisible: false } } }
      }
    ],
  });

  const router = AdminJSExpress.buildRouter(adminJs);
  const app = express();
  app.use(adminJs.options.rootPath, router);
  app.listen(3000, () => console.log('AdminJS запущен на http://localhost:3000/admin'));
};

// Подключение к PostgreSQL через TypeORM
require('typeorm').createConnection({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: [__dirname + '/entities/*.js'],
  synchronize: true,
}).then(startAdminJS);
```

##### `adminjs/entities/Client.js` (пример сущности)
```javascript
const { Entity, PrimaryGeneratedColumn, Column } = require('typeorm');

@Entity()
class Client {
  @PrimaryGeneratedColumn()
  id;

  @Column()
  name;

  @Column({ unique: true })
  email;
}

module.exports = Client;
```

---

### **Как это работает?**
1. **PostgreSQL** — хранит данные.
2. **Hasura** — предоставляет GraphQL API (доступно на `http://localhost:8080`).
3. **AdminJS** — админ-панель на `http://localhost:3000/admin`:
   - Автоматически подхватывает сущности из TypeORM.
   - Позволяет управлять данными через UI.

---

### **Шаги для запуска**
1. Создайте файлы как указано выше.
2. Запустите проект:
   ```bash
   docker-compose up -d
   ```
3. Откройте админ-панель:
   ```
   http://localhost:3000/admin
   ```

---

### **Критические исправления**
1. Убраны несуществующие пакеты (`@adminjs/hasura`).
2. Исправлены зависимости:
   - `@adminjs/typeorm` вместо `@adminjs/postgres`.
   - Добавлен `typeorm` для работы с сущностями.
3. Добавлены TypeORM-сущности для правильного отображения таблиц.

Теперь всё должно работать без ошибок!