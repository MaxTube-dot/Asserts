Вот `docker-compose.yml` файл, который разворачивает PostgreSQL и NocoDB, создает связанные таблицы (клиент, товар, заказ) и заполняет их тестовыми данными:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin
      POSTGRES_DB: nocodb
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - nocodb_network

  nocodb:
    image: nocodb/nocodb:latest
    container_name: nocodb
    depends_on:
      - postgres
    environment:
      NC_DB: pg://postgres:5432?u=admin&p=admin&d=nocodb
      NC_AUTH_JWT_SECRET: my-secret-key
    ports:
      - "8080:8080"
    networks:
      - nocodb_network
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  nocodb_network:
    driver: bridge
```

И файл `init.sql` для инициализации базы данных (должен находиться в той же директории, что и docker-compose.yml):

```sql
-- Создание таблицы клиентов
CREATE TABLE client (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы товаров
CREATE TABLE product (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы заказов
CREATE TABLE "order" (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'pending',
    total_amount DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (client_id) REFERENCES client(id) ON DELETE CASCADE
);

-- Создание таблицы элементов заказа (связь многие-ко-многим между заказом и товаром)
CREATE TABLE order_item (
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES "order"(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE CASCADE
);

-- Заполнение таблицы клиентов тестовыми данными
INSERT INTO client (name, email, phone, address) VALUES
('Иван Иванов', 'ivan@example.com', '+79161234567', 'ул. Ленина, д. 10, кв. 5'),
('Петр Петров', 'petr@example.com', '+79167654321', 'ул. Пушкина, д. 15, кв. 12'),
('Сергей Сергеев', 'sergey@example.com', '+79165554433', 'ул. Гагарина, д. 3, кв. 7');

-- Заполнение таблицы товаров тестовыми данными
INSERT INTO product (name, description, price, stock_quantity) VALUES
('Ноутбук', '15-дюймовый ноутбук с процессором Intel Core i5', 59999.99, 10),
('Смартфон', 'Смартфон с 6.5-дюймовым экраном и 128 ГБ памяти', 34999.99, 15),
('Наушники', 'Беспроводные наушники с шумоподавлением', 8999.99, 20),
('Клавиатура', 'Механическая клавиатура с RGB подсветкой', 4999.99, 8);

-- Заполнение таблицы заказов тестовыми данными
INSERT INTO "order" (client_id, status, total_amount) VALUES
(1, 'completed', 94999.98),
(2, 'processing', 39999.99),
(3, 'pending', 13999.98);

-- Заполнение таблицы элементов заказа тестовыми данными
INSERT INTO order_item (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 59999.99),
(1, 3, 1, 8999.99),
(2, 2, 1, 34999.99),
(3, 3, 1, 8999.99),
(3, 4, 1, 4999.99);
```

Инструкции по использованию:

1. Создайте папку для проекта и поместите в нее оба файла (`docker-compose.yml` и `init.sql`)
2. Запустите сервисы командой: `docker-compose up -d`
3. После запуска:
   - PostgreSQL будет доступен на localhost:5432
   - NocoDB будет доступен на http://localhost:8080
4. Войдите в NocoDB с учетными данными по умолчанию (admin@nocodb.com / password) и сразу увидите созданные таблицы с данными

В NocoDB вы сможете:
- Просматривать и редактировать данные
- Создавать представления
- Настраивать отношения между таблицами
- Создавать API для работы с данными