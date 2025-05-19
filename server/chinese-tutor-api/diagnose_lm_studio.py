"""
Диагностический скрипт для проверки различных способов подключения к LM Studio
"""
import requests
import json
import logging
import sys
import time
import os
import subprocess
import socket

logging.basicConfig(level=logging.INFO,
                   format='%(asctime)s - %(levelname)s - %(message)s',
                   stream=sys.stdout)

# Получение локального IP-адреса
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

# Определяем локальный IP
LOCAL_IP = get_local_ip()

# Возможные адреса LM Studio API
LM_STUDIO_URLS = [
    f"http://{LOCAL_IP}:1234",   # Локальный IP-адрес
    "http://localhost:1234",     # Локальный хост
    "http://127.0.0.1:1234",     # Еще один вариант локального хоста
]

# Добавляем адрес из переменной окружения, если он задан
if "LM_STUDIO_URL" in os.environ and os.environ["LM_STUDIO_URL"] not in LM_STUDIO_URLS:
    LM_STUDIO_URLS.insert(0, os.environ["LM_STUDIO_URL"])

def test_url_with_requests(base_url):
    """Тестирование URL с использованием библиотеки requests"""
    logging.info(f"\nПроверка URL: {base_url} (через requests)")
    
    # Проверка /models
    try:
        logging.info(f"GET {base_url}/v1/models")
        response = requests.get(f"{base_url}/v1/models", timeout=10)
        logging.info(f"Статус: {response.status_code}")
        if response.status_code == 200:
            models = response.json().get("data", [])
            model_ids = [model.get("id") for model in models]
            logging.info(f"Доступные модели: {model_ids}")
            return True, model_ids
        else:
            logging.error(f"Ошибка: {response.text}")
            return False, []
    except Exception as e:
        logging.error(f"Исключение: {e}")
        return False, []

def test_chat_completion(base_url, model_id="gemma-3-4b-qat"):
    """Тестирование запроса к /chat/completions"""
    logging.info(f"\nТестирование chat completion для {base_url}/v1/chat/completions")
    try:
        headers = {"Content-Type": "application/json"}
        
        # Простейший запрос
        data = {
            "model": model_id,
            "messages": [{"role": "user", "content": "Hello!"}],
            "max_tokens": 20
        }
        
        logging.info(f"Отправка запроса к {base_url}/v1/chat/completions")
        logging.debug(f"Данные запроса: {json.dumps(data, indent=2)}")
        
        start_time = time.time()
        response = requests.post(
            f"{base_url}/v1/chat/completions",
            headers=headers,
            json=data,
            timeout=30
        )
        elapsed = time.time() - start_time
        
        logging.info(f"Статус: {response.status_code} (за {elapsed:.2f} сек)")
        
        if response.status_code == 200:
            result = response.json()
            content = result.get("choices", [{}])[0].get("message", {}).get("content", "")
            logging.info(f"Ответ: {content}")
            return True
        else:
            logging.error(f"Ошибка: {response.text}")
            return False
    except Exception as e:
        logging.error(f"Исключение: {e}")
        return False

def check_network_connectivity(host):
    """Проверка сетевого подключения к хосту через ping"""
    try:
        ip = host.replace("http://", "").split(":")[0]
        logging.info(f"\nПроверка сетевого подключения к {ip} через ping")
        
        if sys.platform == "win32":
            # Для Windows
            result = subprocess.run(["ping", "-n", "3", ip], 
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  universal_newlines=True,
                                  timeout=10)
        else:
            # Для Linux/Mac
            result = subprocess.run(["ping", "-c", "3", ip], 
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  universal_newlines=True,
                                  timeout=10)
            
        logging.info(result.stdout)
        return "0% packet loss" in result.stdout or "0% потери" in result.stdout
    except Exception as e:
        logging.error(f"Ошибка при выполнении ping: {e}")
        return False

def main():
    """Основная функция для запуска диагностики"""
    logging.info("Запуск диагностики подключения к LM Studio...")
    
    success_urls = []
    working_models = []
    
    # Проверка сетевой связности
    for url in LM_STUDIO_URLS:
        ip = url.replace("http://", "").split(":")[0]
        if check_network_connectivity(ip):
            logging.info(f"Сетевое подключение к {ip} работает")
        else:
            logging.warning(f"Сетевое подключение к {ip} не работает")
    
    # Проверка URL
    for url in LM_STUDIO_URLS:
        success, models = test_url_with_requests(url)
        if success:
            success_urls.append(url)
            working_models.extend(models)
            
            # Проверяем chat completion для успешного URL
            test_chat_completion(url, models[0] if models else "gemma-3-4b-qat")
    
    # Вывод итогов
    logging.info("\n--- ИТОГИ ДИАГНОСТИКИ ---")
    if success_urls:
        logging.info(f"Рабочие URL: {success_urls}")
        logging.info(f"Доступные модели: {set(working_models)}")
        
        # Выбираем лучший URL и модель для конфигурации
        best_url = success_urls[0]
        best_model = working_models[0] if working_models else "gemma-3-4b-qat"
        
        logging.info("\n--- РЕКОМЕНДАЦИЯ ---")
        logging.info(f"Используйте следующие настройки:")
        logging.info(f"URL: {best_url}/v1")
        logging.info(f"Модель: {best_model}")
        
        # Показываем пример кода для настройки
        logging.info("\n--- ПРИМЕР КОДА ---")
        code_example = f'''
from openai import OpenAI

lm_client = OpenAI(
    base_url="{best_url}/v1",
    api_key="not-needed",
    timeout=60.0
)

response = lm_client.chat.completions.create(
    model="{best_model}",
    messages=[{{"role": "system", "content": "Generate a Chinese exercise..."}}],
    temperature=0.7,
    max_tokens=300
)
'''
        print(code_example)
    else:
        logging.error("Не найдено рабочих подключений к LM Studio!")
        logging.info("""
--- ВОЗМОЖНЫЕ РЕШЕНИЯ ---
1. Проверьте, запущен ли LM Studio
2. Проверьте, загружена ли модель
3. Проверьте настройки API в LM Studio (порт, разрешения)
4. Проверьте сетевые настройки и файрволл
5. Попробуйте перезапустить LM Studio и/или компьютер
""")

if __name__ == "__main__":
    main() 