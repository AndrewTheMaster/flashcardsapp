@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo =================================
echo Chinese Tutor API Server Launcher
echo =================================

REM Create or activate virtual environment
if not exist venv (
    echo [INFO] Creating virtual environment...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo [SUCCESS] Virtual environment created.
) else (
    echo [INFO] Virtual environment already exists.
)

echo [INFO] Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dependencies
echo [INFO] Installing dependencies...
pip install -r requirements.txt

REM Set environment variables
set API_SERVER_PORT=5000
set LM_STUDIO_PORT=1234

REM Get local IP address for non-localhost connections
for /f "tokens=4" %%a in ('route print ^| find " 0.0.0.0"') do (
    if not defined LOCAL_IP set LOCAL_IP=%%a
)

REM Fallback if local IP detection fails
if not defined LOCAL_IP set LOCAL_IP=127.0.0.1

REM Default to localhost address
set LM_STUDIO_URL=http://localhost:%LM_STUDIO_PORT%

REM Disable proxies
set HTTP_PROXY=
set HTTPS_PROXY=
set http_proxy=
set https_proxy=
set NO_PROXY=*,localhost,127.0.0.1,%LOCAL_IP%

echo.
echo [CONFIG] Current settings:
echo - API Server Port: %API_SERVER_PORT%
echo - LM Studio URL: %LM_STUDIO_URL%
echo - Local IP: %LOCAL_IP%
echo.

REM Ask for LM Studio URL
echo LM Studio URLs:
echo 1. Local (http://localhost:%LM_STUDIO_PORT%)
echo 2. Local IP (http://%LOCAL_IP%:%LM_STUDIO_PORT%)
echo 3. Custom URL

choice /c 123 /n /m "Choose LM Studio URL [1]: "
if errorlevel 3 (
    set /p LM_STUDIO_URL="Enter custom LM Studio URL: "
) else if errorlevel 2 (
    set LM_STUDIO_URL=http://%LOCAL_IP%:%LM_STUDIO_PORT%
) else if errorlevel 1 (
    set LM_STUDIO_URL=http://localhost:%LM_STUDIO_PORT%
)

REM Ask for API server port
set /p user_port="Enter API Server Port [%API_SERVER_PORT%]: "
if not "%user_port%"=="" set API_SERVER_PORT=%user_port%

echo.
echo [CONFIG] Updated settings:
echo - API Server Port: %API_SERVER_PORT%
echo - LM Studio URL: %LM_STUDIO_URL%
echo - Local IP: %LOCAL_IP%
echo.

REM Extract host for ping test
for /f "tokens=2 delims=//" %%a in ("%LM_STUDIO_URL%") do set LM_HOST_PORT=%%a
for /f "tokens=1 delims=:" %%a in ("%LM_HOST_PORT%") do set LM_HOST=%%a

echo [INFO] Testing connection to host: %LM_HOST%

REM Simple ping test
ping -n 2 %LM_HOST% >nul
if %errorlevel% neq 0 (
    echo [WARNING] Cannot ping host %LM_HOST%. Network connectivity issue.
    echo [WARNING] Server may not work properly with this host!
    
    choice /c YN /n /m "Continue anyway? [Y/N]: "
    if errorlevel 2 exit /b 1
) else (
    echo [INFO] Host %LM_HOST% is reachable via ping.
)

echo.
echo [START] Launching server with settings:
echo - Port: %API_SERVER_PORT%
echo - LM Studio URL: %LM_STUDIO_URL%
echo - Local IP: %LOCAL_IP%
echo.

REM Start server with explicit numeric port
python run_server.py --port=%API_SERVER_PORT% --lm-url=%LM_STUDIO_URL%

pause 