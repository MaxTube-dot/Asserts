Да, существуют **готовые решения для работы с моделями сущностей в Python**, которые позволяют:

1. **Описать структуру таблиц в виде Python-классов (моделей)**.
2. **Автоматически создать эти таблицы в выбранной СУБД** — в вашем случае, в PostgreSQL.

### Наиболее популярные подходы

| Решение         | Описание                                                                                       | Поддержка PostgreSQL |
|-----------------|------------------------------------------------------------------------------------------------|----------------------|
| SQLAlchemy ORM  | Декларируете модели как Python-классы, затем вызываете создание таблиц по этим моделям         | Да                   |
| SQLModel        | Современная надстройка над SQLAlchemy, синтаксис похож на Pydantic, поддерживает автосоздание   | Да                   |
| Django ORM      | Описываете модели, миграциями создаёте таблицы в базе                                          | Да                   |
| Pydantic + Alembic | Для схем и миграций, но требует настройки                                                     | Да                   |

#### Пример на SQLModel (современный и простой вариант):

```python
from sqlmodel import SQLModel, Field, create_engine

class User(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    name: str
    email: str

engine = create_engine("postgresql://user:password@localhost/dbname")
SQLModel.metadata.create_all(engine)
```
- После запуска этого кода в вашей базе PostgreSQL будут созданы таблицы по описанным моделям[1].

#### Пример на SQLAlchemy:

```python
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class User(Base):
    __tablename__ = 'user'
    id = Column(Integer, primary_key=True)
    name = Column(String)
    email = Column(String)

engine = create_engine("postgresql://user:password@localhost/dbname")
Base.metadata.create_all(engine)
```
- Аналогично, таблицы будут созданы по описанным моделям.

**Итог:**  
- Вы описываете сущности в Python (например, через SQLModel или SQLAlchemy).
- Подключаетесь к PostgreSQL.
- Вызываете метод для создания таблиц (`metadata.create_all(engine)`).
- Таблицы создаются автоматически по вашей модели.

Это стандартная и широко используемая практика в Python-разработке для работы с реляционными базами данных[1].

Если нужно визуальное моделирование и экспорт DDL — можно использовать инструменты вроде Luna Modeler, которые позволяют создать схему и экспортировать SQL-скрипт для PostgreSQL[2].

Источники
[1] Create a Table with SQLModel - Use the Engine https://sqlmodel.tiangolo.com/tutorial/create-db-and-table/
[2] CREATE TABLE in PostgreSQL | Example - Luna Modeler https://www.datensen.com/blog/data-modeling/sql-create-table-postgresql/
[3] Documentation: 17: CREATE TABLE - PostgreSQL https://www.postgresql.org/docs/current/sql-createtable.html
[4] How to build an Entity Framework model from a PostgreSQL schema? https://stackoverflow.com/questions/35248783/how-to-build-an-entity-framework-model-from-a-postgresql-schema
[5] Documentation: 17: CREATE TABLE AS - PostgreSQL https://www.postgresql.org/docs/current/sql-createtableas.html
[6] How to generate the "create table" sql statement for an ... https://stackoverflow.com/questions/2593803/how-to-generate-the-create-table-sql-statement-for-an-existing-table-in-postgr
[7] Postgres Schema Tutorial: How to Create Schema in PostgreSQL https://estuary.dev/blog/postgres-schema/
[8] Transfer data between databases with PostgreSQL - Stack Overflow https://stackoverflow.com/questions/3049864/transfer-data-between-databases-with-postgresql
[9] 5 Ways to Get Table Creation Information in Postgres - Crunchy Data https://www.crunchydata.com/blog/5-ways-to-get-table-creation-information-in-postgres
[10] Create and Delete Databases and Tables in PostgreSQL - Prisma https://www.prisma.io/dataguide/postgresql/create-and-delete-databases-and-tables
