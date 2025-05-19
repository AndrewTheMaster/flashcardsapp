@echo off
chcp 65001 > nul
echo =================================
echo Chinese Tutor API Server - Config
echo =================================

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo Installing dependencies...
pip install -r requirements.txt

REM Get local IP address
for /f "tokens=4" %%a in ('route print ^| find " 0.0.0.0"') do (
    if not defined LOCAL_IP set LOCAL_IP=%%a
)

REM Fallback if local IP detection fails
if not defined LOCAL_IP set LOCAL_IP=127.0.0.1

REM Default settings
set API_SERVER_PORT=5000
set LM_STUDIO_PORT=1234
set LM_STUDIO_URL=http://localhost:%LM_STUDIO_PORT%

echo.
echo *** SERVER CONFIGURATION ***
echo.

echo Current port: %API_SERVER_PORT%
echo Enter new API Server Port (or press Enter for default 5000): 
set /p new_port=
if not "%new_port%"=="" (
    set API_SERVER_PORT=%new_port%
)

echo.
echo LM Studio connection options:
echo 1. Local (http://localhost:%LM_STUDIO_PORT%)
echo 2. Local IP (http://%LOCAL_IP%:%LM_STUDIO_PORT%)
echo 3. Custom URL
echo.
echo Current: %LM_STUDIO_URL%

choice /c 123 /n /m "Choose LM Studio connection [1]: "
if errorlevel 3 (
    echo Enter custom LM Studio URL: 
    set /p LM_STUDIO_URL=
) else if errorlevel 2 (
    set LM_STUDIO_URL=http://%LOCAL_IP%:%LM_STUDIO_PORT%
) else if errorlevel 1 (
    set LM_STUDIO_URL=http://localhost:%LM_STUDIO_PORT%
)

echo.
echo *** CONFIGURATION SUMMARY ***
echo - API Server Port: %API_SERVER_PORT%
echo - LM Studio URL: %LM_STUDIO_URL%
echo - Local IP: %LOCAL_IP%
echo.

REM Export as environment variables for Python to use
set "API_SERVER_PORT=%API_SERVER_PORT%"
set "LM_STUDIO_URL=%LM_STUDIO_URL%"

echo Starting API Server with these settings...
python run_server.py --port=%API_SERVER_PORT% --lm-url=%LM_STUDIO_URL%

pause 