"""
Скрипт для тестирования соединения с LM Studio
"""
import requests
import json
import logging
import sys
import time
import os
import socket
from openai import OpenAI

logging.basicConfig(level=logging.DEBUG, 
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                   stream=sys.stdout)

# Функция для получения локального IP-адреса
def get_local_ip():
    try:
        # Создаем сокет, подключаемый к внешнему адресу
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        logging.error(f"Ошибка при получении локального IP: {e}")
        return "127.0.0.1"  # Fallback на localhost

# Get local IP
local_ip = get_local_ip()
logging.info(f"Обнаружен локальный IP: {local_ip}")

# Get LM Studio URL from environment or use default
LM_STUDIO_URL = os.environ.get("LM_STUDIO_URL", "http://localhost:1234")

# Если URL не указан явно, предлагаем варианты
if LM_STUDIO_URL == "http://localhost:1234" and len(sys.argv) > 1:
    if sys.argv[1] == "--local-ip":
        LM_STUDIO_URL = f"http://{local_ip}:1234"
        logging.info(f"Используем локальный IP-адрес: {LM_STUDIO_URL}")

logging.info(f"Тестирование соединения с LM Studio на {LM_STUDIO_URL}")

# Тестирование через requests напрямую
def test_with_requests():
    """Тестирование соединения с LM Studio через requests напрямую"""
    logging.info(f"Тестирование соединения с LM Studio (requests) на {LM_STUDIO_URL}")
    
    # Тест 1: GET запрос к /models
    try:
        logging.info(f"Тест 1: GET {LM_STUDIO_URL}/v1/models")
        response = requests.get(f"{LM_STUDIO_URL}/v1/models")
        logging.info(f"Статус: {response.status_code}")
        logging.info(f"Ответ: {response.text}")
    except Exception as e:
        logging.error(f"Ошибка: {e}")
    
    # Тест 2: Простой POST запрос к /chat/completions
    try:
        logging.info(f"\nТест 2: POST {LM_STUDIO_URL}/v1/chat/completions (простой запрос)")
        headers = {"Content-Type": "application/json"}
        data = {
            "model": "gemma-3-4b-it-qat",
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 50
        }
        response = requests.post(
            f"{LM_STUDIO_URL}/v1/chat/completions",
            headers=headers,
            data=json.dumps(data)
        )
        logging.info(f"Статус: {response.status_code}")
        logging.info(f"Ответ: {response.text[:200]}...")
    except Exception as e:
        logging.error(f"Ошибка: {e}")
    
    # Тест 3: POST запрос с китайской темой
    try:
        logging.info(f"\nТест 3: POST {LM_STUDIO_URL}/v1/chat/completions (китайский)")
        headers = {"Content-Type": "application/json"}
        data = {
            "model": "gemma-3-4b-it-qat",
            "messages": [{"role": "user", "content": "生成一个中文句子"}], # "Создай китайское предложение"
            "max_tokens": 50
        }
        response = requests.post(
            f"{LM_STUDIO_URL}/v1/chat/completions",
            headers=headers,
            data=json.dumps(data)
        )
        logging.info(f"Статус: {response.status_code}")
        logging.info(f"Ответ: {response.text[:200]}...")
    except Exception as e:
        logging.error(f"Ошибка: {e}")

# Тестирование через OpenAI клиент
def test_with_openai_client():
    """Тестирование соединения с LM Studio через OpenAI клиент"""
    logging.info(f"\nТестирование соединения с LM Studio (OpenAI) на {LM_STUDIO_URL}")
    
    # Инициализация клиента
    client = OpenAI(
        base_url=f"{LM_STUDIO_URL}/v1",
        api_key="not-needed",
        timeout=60.0
    )
    
    # Тест 1: Список моделей
    try:
        logging.info("Тест 1: Список моделей")
        models = client.models.list()
        logging.info(f"Доступные модели: {[model.id for model in models.data]}")
    except Exception as e:
        logging.error(f"Ошибка: {e}")
    
    # Тест 2: Простой запрос к чату
    try:
        logging.info("\nТест 2: Простой запрос к чату")
        response = client.chat.completions.create(
            model="gemma-3-4b-it-qat",
            messages=[{"role": "user", "content": "Hello"}],
            max_tokens=50
        )
        logging.info(f"Ответ: {response.choices[0].message.content}")
    except Exception as e:
        logging.error(f"Ошибка: {e}")
    
    # Тест 3: Запрос с заданием на китайском
    try:
        logging.info("\nТест 3: Запрос с китайским заданием")
        response = client.chat.completions.create(
            model="gemma-3-4b-it-qat",
            messages=[{
                "role": "system", 
                "content": """Generate a Chinese language exercise.
Format:
Sentence: [a sentence with [BLANK]]
Options: [option1, option2, option3]
Topic: food"""
            }],
            temperature=0.5,
            max_tokens=100
        )
        logging.info(f"Ответ: {response.choices[0].message.content}")
    except Exception as e:
        logging.error(f"Ошибка: {e}")

if __name__ == "__main__":
    test_with_requests()
    test_with_openai_client() 