Если ваши данные находятся в отдельном файле, например, в формате CSV, вы можете использовать библиотеку pandas для загрузки данных из этого файла. Давайте предположим, что ваш файл называется addresses.csv и имеет следующую структуру:

address1,address2,label
"п. Остафьево, район Село Остафьево, д. 3","п. Остафьево, район Село Остафьево, д. 3",1
"г. Москва, ул. Ленина, д. 10","г. Москва, ул. Ленина, д. 11",0
"п. Остафьево, район Село Остафьево, д. 4","п. Остафьево, район Село Остафьево, д. 4",1
"г. Москва, ул. Пушкина, д. 12","г. Москва, ул. Пушкина, д. 12",1


Вот обновленный код с учетом чтения данных из файла:

▎Шаг 1: Импорт необходимых библиотек и загрузка данных

import pandas as pd

# Загрузка данных из CSV файла
df = pd.read_csv('addresses.csv')

# Проверка загруженных данных
print(df.head())


▎Шаг 2: Векторизация данных и обучение модели

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import numpy as np

# Векторизация адресов
vectorizer = TfidfVectorizer()

# Объединяем адреса для векторизации
X1 = vectorizer.fit_transform(df['address1'])
X2 = vectorizer.transform(df['address2'])

# Объединяем векторы в один массив
X = np.hstack((X1.toarray(), X2.toarray()))

# Метки
y = df['label']

# Разделение на обучающую и тестовую выборки
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Обучение модели SVM
model = SVC(kernel='linear')
model.fit(X_train, y_train)

# Прогнозирование
y_pred = model.predict(X_test)

# Оценка модели
print("Accuracy:", accuracy_score(y_test, y_pred))
print("Classification Report:\n", classification_report(y_test, y_pred))


▎Шаг 3: Пример использования модели для новых строк

# Пример использования модели для новых строк
new_addresses = [
    ("п. Остафьево, район Село Остафьево, д. 3", "п. Остафьево, район Село Остафьево, д. 3"),
    ("г. Москва, ул. Ленина, д. 10", "г. Москва, ул. Ленина, д. 11")
]

for addr1, addr2 in new_addresses:
    vec1 = vectorizer.transform([addr1])
    vec2 = vectorizer.transform([addr2])
    combined_vec = np.hstack((vec1.toarray(), vec2.toarray()))
    prediction = model.predict(combined_vec)
    print(f"Адреса: '{addr1}' и '{addr2}' - {'Одинаковые' if prediction[0] == 1 else 'Разные'}")


▎Объяснение изменений:

1. Загрузка данных: Мы используем pd.read_csv() для загрузки данных из файла addresses.csv.

2. Проверка данных: Выводим первые несколько строк загруженного DataFrame для проверки корректности.

3. Остальная часть кода остается без изменений и выполняет ту же логику: векторизация адресов, обучение модели и прогнозирование.

▎Запуск кода

Убедитесь, что файл addresses.csv находится в том же каталоге, что и ваш скрипт Python, или укажите полный путь к файлу.

Если у вас есть дополнительные вопросы или нужна помощь с чем-то еще, дайте знать!