FROM python:3.9-slim

WORKDIR /app

# Установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование модели и кода
COPY ./my_bert_model /app/my_bert_model
COPY ./app.py /app/

# Запуск API
CMD ["python", "app.py"] 