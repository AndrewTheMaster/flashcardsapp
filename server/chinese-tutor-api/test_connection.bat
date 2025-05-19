@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo =================================
echo LM Studio Connection Tester
echo =================================

REM Получение локального IP-адреса
for /f "tokens=4" %%a in ('route print ^| find " 0.0.0.0"') do (
    if not defined LOCAL_IP set LOCAL_IP=%%a
)

REM Fallback если определение IP не удалось
if not defined LOCAL_IP set LOCAL_IP=127.0.0.1

REM Настройки по умолчанию
set LM_STUDIO_PORT=1234
set LM_STUDIO_URL=http://localhost:%LM_STUDIO_PORT%

REM Проверка, есть ли аргумент с URL
if not "%~1"=="" (
    set LM_STUDIO_URL=%~1
)

echo LM Studio URLs:
echo 1. Local (http://localhost:%LM_STUDIO_PORT%)
echo 2. Local IP (http://%LOCAL_IP%:%LM_STUDIO_PORT%)
echo 3. Custom URL
echo.

REM Выбор URL из предложенных
choice /c 123 /n /m "Choose LM Studio URL [1]: "
if errorlevel 3 (
    set /p LM_STUDIO_URL="Enter custom LM Studio URL: "
) else if errorlevel 2 (
    set LM_STUDIO_URL=http://%LOCAL_IP%:%LM_STUDIO_PORT%
) else if errorlevel 1 (
    set LM_STUDIO_URL=http://localhost:%LM_STUDIO_PORT%
)

echo.
echo [INFO] Testing connection to %LM_STUDIO_URL%
echo.

REM Активируем виртуальное окружение, если есть
if exist venv\Scripts\activate.bat (
    echo [INFO] Activating virtual environment...
    call venv\Scripts\activate.bat
)

REM Создаем временный Python-скрипт для извлечения хоста и порта
echo from urllib.parse import urlparse > url_parser.py
echo import sys >> url_parser.py
echo try: >> url_parser.py
echo     url = '%LM_STUDIO_URL%' >> url_parser.py
echo     parsed = urlparse(url) >> url_parser.py
echo     host = parsed.netloc.split(':')[0] >> url_parser.py
echo     port = parsed.port or (443 if parsed.scheme == 'https' else 80) >> url_parser.py
echo     print(f"{host}|{port}") >> url_parser.py
echo except Exception as e: >> url_parser.py
echo     print("localhost|1234") >> url_parser.py

REM Запускаем Python-скрипт и получаем результат
for /f "usebackq" %%i in (`python url_parser.py`) do set URL_PARTS=%%i
del url_parser.py

for /f "tokens=1,2 delims=|" %%a in ("%URL_PARTS%") do (
    set LM_HOST=%%a
    set LM_PORT=%%b
)

echo [INFO] Extracted host: %LM_HOST%, port: %LM_PORT%
echo.

REM Первый тест: проверка доступности хоста
echo [TEST 1] Testing host connectivity...
set TEMP_FILE=%TEMP%\connection_test_output.txt

REM Создаем временный Python-скрипт для теста TCP-соединения
echo import sys > tcp_test.py
echo import socket >> tcp_test.py
echo try: >> tcp_test.py
echo     host = '%LM_HOST%' >> tcp_test.py
echo     port = %LM_PORT% >> tcp_test.py
echo     print(f"Checking host {host} on port {port}") >> tcp_test.py
echo     sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM) >> tcp_test.py
echo     sock.settimeout(5) >> tcp_test.py
echo     result = sock.connect_ex((host, port)) >> tcp_test.py
echo     sock.close() >> tcp_test.py
echo     if result == 0: >> tcp_test.py
echo         print("SUCCESS: Host is reachable") >> tcp_test.py
echo         sys.exit(0) >> tcp_test.py
echo     else: >> tcp_test.py
echo         print(f"ERROR: Cannot connect to host. Error code: {result}") >> tcp_test.py
echo         sys.exit(1) >> tcp_test.py
echo except Exception as e: >> tcp_test.py
echo     print(f"ERROR: {str(e)}") >> tcp_test.py
echo     sys.exit(1) >> tcp_test.py

python tcp_test.py > %TEMP_FILE% 2>&1
del tcp_test.py

type %TEMP_FILE%
findstr /C:"SUCCESS" %TEMP_FILE% >nul
if %errorlevel% neq 0 (
    echo [WARNING] Host connectivity test failed. Continuing with API tests anyway...
) else (
    echo [INFO] Host connectivity test passed
)

echo.
echo [TEST 2] Testing API using direct HTTP request...

REM Создаем временный Python-скрипт для HTTP-запроса
echo import sys > http_test.py
echo import requests >> http_test.py
echo try: >> http_test.py
echo     url = '%LM_STUDIO_URL%/v1/models' >> http_test.py
echo     print(f"Sending GET request to {url}") >> http_test.py
echo     response = requests.get(url, timeout=10) >> http_test.py
echo     if response.status_code == 200: >> http_test.py
echo         print(f"SUCCESS: HTTP status {response.status_code}") >> http_test.py
echo         models = response.json().get('data', []) >> http_test.py
echo         print(f"Models available: {len(models)}") >> http_test.py
echo         for model in models: >> http_test.py
echo             print(f"- {model.get('id', 'unknown')}") >> http_test.py
echo         sys.exit(0) >> http_test.py
echo     else: >> http_test.py
echo         print(f"ERROR: HTTP status {response.status_code}") >> http_test.py
echo         print(f"Response: {response.text}") >> http_test.py
echo         sys.exit(1) >> http_test.py
echo except Exception as e: >> http_test.py
echo     print(f"ERROR: {str(e)}") >> http_test.py
echo     sys.exit(1) >> http_test.py

python http_test.py > %TEMP_FILE% 2>&1
del http_test.py

type %TEMP_FILE%
findstr /C:"SUCCESS" %TEMP_FILE% >nul
if %errorlevel% neq 0 (
    echo [ERROR] API HTTP test failed
) else (
    echo [INFO] API HTTP test passed
)

echo.
echo [TEST 3] Testing API using OpenAI client...

REM Создаем временный Python-скрипт для OpenAI-клиента
echo import sys > openai_test.py
echo try: >> openai_test.py
echo     from openai import OpenAI >> openai_test.py
echo     print(f"Initializing OpenAI client with URL: {'%LM_STUDIO_URL%'}") >> openai_test.py
echo     client = OpenAI( >> openai_test.py
echo         base_url='%LM_STUDIO_URL%/v1', >> openai_test.py
echo         api_key="not-needed", >> openai_test.py
echo         timeout=15.0 >> openai_test.py
echo     ) >> openai_test.py
echo     print("Sending models.list() request") >> openai_test.py
echo     models = client.models.list() >> openai_test.py
echo     print(f"SUCCESS: Connected successfully") >> openai_test.py
echo     print("Available models:") >> openai_test.py
echo     for model in models.data: >> openai_test.py
echo         print(f"- {model.id}") >> openai_test.py
echo     sys.exit(0) >> openai_test.py
echo except Exception as e: >> openai_test.py
echo     print(f"ERROR: {str(e)}") >> openai_test.py
echo     sys.exit(1) >> openai_test.py

python openai_test.py > %TEMP_FILE% 2>&1
del openai_test.py

type %TEMP_FILE%
findstr /C:"SUCCESS" %TEMP_FILE% >nul
if %errorlevel% neq 0 (
    echo [ERROR] OpenAI client test failed
) else (
    echo [INFO] OpenAI client test passed
)

echo.
echo =================================
echo Connection test completed!
echo =================================

pause 