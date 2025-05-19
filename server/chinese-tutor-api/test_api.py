"""
Скрипт для тестирования API запросов к Flask серверу
"""
import requests
import json
import time
import logging
import sys
import os

logging.basicConfig(level=logging.INFO,
                   format='%(asctime)s - %(levelname)s - %(message)s',
                   stream=sys.stdout)

# Disable proxy settings
os.environ['NO_PROXY'] = 'localhost,127.0.0.1'

# URL сервера
SERVER_PORT = int(os.environ.get("API_SERVER_PORT", 5000))
BASE_URL = f"http://localhost:{SERVER_PORT}"
logging.info(f"Using API server at {BASE_URL}")

def create_no_proxy_session():
    """Create a session that bypasses proxies"""
    session = requests.Session()
    session.trust_env = False  # Don't use system proxy settings
    return session

def test_connection():
    """Тестирование соединения с сервером"""
    logging.info("Проверка соединения с сервером...")
    try:
        session = create_no_proxy_session()
        response = session.get(f"{BASE_URL}/test-connection")
        if response.status_code == 200:
            data = response.json()
            logging.info(f"Соединение успешно. Доступные модели: {data['models']}")
        else:
            logging.error(f"Ошибка соединения: {response.status_code}, {response.text}")
    except Exception as e:
        logging.error(f"Исключение при подключении: {e}")
        import traceback
        logging.error(traceback.format_exc())

def test_generate_simple():
    """Простой тест генерации"""
    logging.info("\nПростой тест генерации...")
    try:
        session = create_no_proxy_session()
        data = {"topic": "food", "difficulty": "beginner"}
        logging.info(f"Отправка прямого запроса к {BASE_URL}/generate...")
        response = session.post(f"{BASE_URL}/generate", json=data)
        logging.info(f"Статус: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            logging.info(f"Результат: {json.dumps(result, ensure_ascii=False, indent=2)}")
        else:
            logging.error(f"Ошибка: {response.text}")
    except Exception as e:
        logging.error(f"Исключение: {e}")
        import traceback
        logging.error(traceback.format_exc())

def test_generate_multiple_topics():
    """Тестирование генерации с разными темами"""
    topics = ["food", "family", "hobby", "travel", "school"]
    difficulties = ["beginner", "intermediate"]
    
    session = create_no_proxy_session()
    
    for topic in topics:
        for difficulty in difficulties:
            logging.info(f"\nТест генерации: тема={topic}, сложность={difficulty}")
            try:
                data = {"topic": topic, "difficulty": difficulty}
                response = session.post(f"{BASE_URL}/generate", json=data)
                logging.info(f"Статус: {response.status_code}")
                if response.status_code == 200:
                    result = response.json()
                    logging.info(f"Результат: {json.dumps(result, ensure_ascii=False, indent=2)}")
                else:
                    logging.error(f"Ошибка: {response.text}")
                
                # Пауза между запросами
                time.sleep(2)
            except Exception as e:
                logging.error(f"Исключение: {e}")
                import traceback
                logging.error(traceback.format_exc())

if __name__ == "__main__":
    test_connection()
    test_generate_simple()
    # Раскомментируйте, чтобы тестировать разные темы
    # test_generate_multiple_topics() 