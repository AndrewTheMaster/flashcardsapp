"""
Скрипт для тестирования генерации упражнений с конкретными китайскими словами
"""
import requests
import json
import logging
import sys
import time
import os
from tabulate import tabulate

logging.basicConfig(level=logging.INFO,
                   format='%(asctime)s - %(levelname)s - %(message)s',
                   stream=sys.stdout)

# Disable proxy settings
os.environ['NO_PROXY'] = 'localhost,127.0.0.1'

# URL сервера
SERVER_PORT = int(os.environ.get("API_SERVER_PORT", 5000))
BASE_URL = f"http://localhost:{SERVER_PORT}"
logging.info(f"Using API server at {BASE_URL}")

# Тестовые слова разных уровней HSK
TEST_WORDS = [
    {"word": "服务器", "hsk_level": 4, "desc": "Сервер (компьютер)"},
    {"word": "电脑", "hsk_level": 2, "desc": "Компьютер"},
    {"word": "学习", "hsk_level": 1, "desc": "Учиться"},
    {"word": "美丽", "hsk_level": 2, "desc": "Красивый"},
    {"word": "发展", "hsk_level": 5, "desc": "Развитие"},
]

def test_connection():
    """Проверка соединения с сервером"""
    try:
        # Create a session without proxy
        session = requests.Session()
        session.trust_env = False  # Ignore any proxy settings
        
        response = session.get(f"{BASE_URL}/test-connection")
        if response.status_code == 200:
            data = response.json()
            logging.info(f"Соединение успешно. Доступные модели: {data.get('models', [])}")
            return True
        else:
            logging.error(f"Ошибка соединения: {response.status_code}, {response.text}")
            return False
    except Exception as e:
        logging.error(f"Исключение при проверке соединения: {e}")
        return False

def test_generate_exercise(word_info):
    """Тестирование генерации упражнения для конкретного слова"""
    word = word_info["word"]
    hsk_level = word_info["hsk_level"]
    desc = word_info["desc"]
    
    logging.info(f"\nТестирование слова: {word} ({desc}), HSK {hsk_level}")
    try:
        # Подготовка данных запроса
        data = {
            "word": word,
            "hsk_level": hsk_level,
            "system_language": "ru"
        }
        
        # Create a session without proxy
        session = requests.Session()
        session.trust_env = False
        
        # Отправка запроса
        logging.info(f"Отправка прямого запроса к {BASE_URL}/generate...")
        response = session.post(f"{BASE_URL}/generate", json=data)
        
        # Вывод результата
        logging.info(f"Статус ответа: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            
            # Вывод результата в удобном формате
            print("\n" + "="*50)
            print(f"СЛОВО: {word} ({desc}) - HSK {hsk_level}")
            print("="*50)
            print(f"Предложение с пропуском: {result.get('sentence_with_gap', 'Н/Д')}")
            print(f"Пиньинь: {result.get('pinyin', 'Н/Д')}")
            
            options = result.get('options', [])
            answer = result.get('answer', '')
            
            # Создаем таблицу вариантов
            options_table = []
            for opt in options:
                is_correct = "✓" if opt == answer else " "
                options_table.append([f"{is_correct}", f"{opt}"])
            
            print("\nВарианты ответов:")
            print(tabulate(options_table, tablefmt="simple"))
            print("="*50)
            
            return True
        else:
            logging.error(f"Ошибка: {response.text}")
            return False
    except Exception as e:
        logging.error(f"Исключение при тестировании: {e}")
        import traceback
        logging.error(traceback.format_exc())
        return False

def run_tests():
    """Запуск всех тестов"""
    logging.info("Начало тестирования...")
    
    # Проверка соединения
    if not test_connection():
        logging.error("Тестирование прервано из-за проблем с соединением")
        return
    
    # Тестирование генерации упражнений
    success_count = 0
    for word_info in TEST_WORDS:
        if test_generate_exercise(word_info):
            success_count += 1
        time.sleep(2)  # Пауза между запросами
    
    # Итоговый результат
    logging.info(f"\nИтог: успешно {success_count} из {len(TEST_WORDS)} тестов")

if __name__ == "__main__":
    try:
        run_tests()
    except KeyboardInterrupt:
        logging.info("Тестирование прервано пользователем")
    except Exception as e:
        logging.error(f"Неожиданная ошибка: {e}")
        raise 