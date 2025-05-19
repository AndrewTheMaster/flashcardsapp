#!/bin/bash
# Скрипт запуска Chinese Tutor API Server для Linux/macOS

# Установка цветовых кодов для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Chinese Tutor API Server Launcher${NC}"
echo -e "${BLUE}=================================${NC}"

# Проверка наличия Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[ОШИБКА] Python не найден. Пожалуйста, установите Python 3.8 или выше.${NC}"
    exit 1
fi

# Проверка версии Python
python_version=$(python3 --version | sed 's/Python //')
python_major=$(echo $python_version | cut -d. -f1)
python_minor=$(echo $python_version | cut -d. -f2)

if [ "$python_major" -lt 3 ] || ([ "$python_major" -eq 3 ] && [ "$python_minor" -lt 8 ]); then
    echo -e "${RED}[ОШИБКА] Требуется Python 3.8 или выше. Обнаружена версия: $python_version${NC}"
    exit 1
fi

echo -e "${GREEN}[ИНФО] Версия Python: $python_version${NC}"

# Проверка и установка venv
if [ ! -d "venv" ]; then
    echo -e "${BLUE}[ИНФО] Создание виртуального окружения...${NC}"
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ОШИБКА] Не удалось создать виртуальное окружение.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[УСПЕХ] Виртуальное окружение создано.${NC}"
else
    echo -e "${BLUE}[ИНФО] Виртуальное окружение уже существует.${NC}"
fi

# Активация виртуального окружения
echo -e "${BLUE}[ИНФО] Активация виртуального окружения...${NC}"
source venv/bin/activate
if [ $? -ne 0 ]; then
    echo -e "${RED}[ОШИБКА] Не удалось активировать виртуальное окружение.${NC}"
    exit 1
fi

# Установка зависимостей
echo -e "${BLUE}[ИНФО] Установка зависимостей...${NC}"
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo -e "${RED}[ОШИБКА] Не удалось установить зависимости.${NC}"
    exit 1
fi

# Проверка и настройка необходимых директорий
if [ ! -d "models" ]; then
    echo -e "${BLUE}[ИНФО] Создание директории для моделей...${NC}"
    mkdir -p models
fi

# Настройка переменных окружения
API_SERVER_PORT=5000
LM_STUDIO_URL="http://localhost:1234"

# Отключение настроек прокси
unset HTTP_PROXY
unset HTTPS_PROXY
export NO_PROXY=localhost,127.0.0.1,::1

# Получение локального IP-адреса для подключения с мобильных устройств
LOCAL_IP=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(ip addr 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
fi
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="127.0.0.1"
fi

echo -e "\n${BLUE}[КОНФИГУРАЦИЯ] Текущие настройки:${NC}"
echo -e "- API Server Port: ${GREEN}$API_SERVER_PORT${NC}"
echo -e "- LM Studio URL: ${GREEN}$LM_STUDIO_URL${NC}"
echo -e "- Локальный IP: ${GREEN}$LOCAL_IP${NC}"

# Запрос адреса LM Studio
read -p "Введите URL LM Studio [$LM_STUDIO_URL]: " user_lm_url
if [ ! -z "$user_lm_url" ]; then
    LM_STUDIO_URL=$user_lm_url
fi

# Запрос порта API сервера
read -p "Введите порт API сервера [$API_SERVER_PORT]: " user_port
if [ ! -z "$user_port" ]; then
    API_SERVER_PORT=$user_port
fi

echo -e "\n${BLUE}[КОНФИГУРАЦИЯ] Обновленные настройки:${NC}"
echo -e "- API Server Port: ${GREEN}$API_SERVER_PORT${NC}"
echo -e "- LM Studio URL: ${GREEN}$LM_STUDIO_URL${NC}"
echo -e "- URL для мобильного приложения: ${GREEN}http://$LOCAL_IP:$API_SERVER_PORT${NC}"

# Улучшенная проверка доступности LM Studio
echo -e "\n${BLUE}[ТЕСТ] Проверка подключения к LM Studio...${NC}"
if python3 -c "
import requests
import sys

try:
    # Попробуем HTTP-запрос сначала
    print('Проверка через HTTP-запрос...')
    r = requests.get('$LM_STUDIO_URL/v1/models', timeout=10)
    if r.status_code == 200:
        print('HTTP-подключение успешно!')
        print('Доступные модели:', r.json().get('data', []))
        exit(0)
    else:
        print(f'HTTP-подключение вернуло ошибку {r.status_code}')
        exit(1)
except Exception as e:
    print(f'HTTP-ошибка: {e}')
    
    # Попробуем через OpenAI клиент как запасной вариант
    try:
        print('Проверка через OpenAI клиент...')
        from openai import OpenAI
        client = OpenAI(base_url='$LM_STUDIO_URL/v1', api_key='not-needed', timeout=5.0)
        models = [model.id for model in client.models.list().data]
        print('OpenAI-подключение успешно!')
        print('Доступные модели:', models)
        exit(0)
    except Exception as e2:
        print(f'OpenAI-ошибка: {e2}')
        
        # Проверяем доступность хоста через ping
        print('Проверка доступности хоста...')
        host = '$LM_STUDIO_URL'.replace('http://', '').replace('https://', '').split(':')[0]
        import subprocess
        ping_result = subprocess.run(['ping', '-c', '2', host], 
                                   stdout=subprocess.PIPE, 
                                   stderr=subprocess.PIPE,
                                   universal_newlines=True)
        if ping_result.returncode == 0:
            print(f'Хост {host} доступен, но API не отвечает')
        else:
            print(f'Хост {host} недоступен. Проблема с сетью.')
        exit(1)
" 2>/dev/null; then
    echo -e "${GREEN}[УСПЕХ] Подключение к LM Studio установлено.${NC}"
else
    echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] Не удалось подключиться к LM Studio по адресу $LM_STUDIO_URL${NC}"
    
    # Извлекаем хост из URL для проверки сетевой доступности
    LM_HOST=$(echo "$LM_STUDIO_URL" | sed -e 's|^[^/]*//||' -e 's|[:/].*$||')
    
    if ping -c 2 $LM_HOST >/dev/null 2>&1; then
        echo -e "${BLUE}[ИНФО] Хост $LM_HOST доступен через ping, но API не отвечает.${NC}"
        echo -e "${BLUE}[ИНФО] Убедитесь, что LM Studio запущен и API включен.${NC}"
    else
        echo -e "${RED}[ОШИБКА] Хост $LM_HOST недоступен. Проблема с сетевым подключением.${NC}"
    fi
    
    echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] Сервер будет запущен, но функции генерации упражнений могут быть недоступны.${NC}"
    
    read -p "Продолжить запуск сервера? (y/n): " continue
    if [[ ! "$continue" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[ИНФО] Выход из программы.${NC}"
        exit 1
    fi
fi

echo -e "\n${BLUE}[ЗАПУСК] Запуск сервера с настройками:${NC}"
echo -e "- Port: ${GREEN}$API_SERVER_PORT${NC}"
echo -e "- LM Studio URL: ${GREEN}$LM_STUDIO_URL${NC}"
echo -e "- URL для мобильного приложения: ${GREEN}http://$LOCAL_IP:$API_SERVER_PORT${NC}"
echo -e "- URL для Android эмулятора: ${GREEN}http://10.0.2.2:$API_SERVER_PORT${NC}"
echo

# Запуск сервера
python3 run_server.py --port=$API_SERVER_PORT --lm-url=$LM_STUDIO_URL 