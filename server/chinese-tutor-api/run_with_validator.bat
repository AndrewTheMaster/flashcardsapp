@echo off
echo Starting Chinese Tutor API with BERT validator...
echo.

REM Determine local IP address
FOR /F "tokens=3 delims=: " %%G IN ('netsh interface ip show address "Wi-Fi" ^| findstr "IP Address"') DO SET local_ip=%%G

IF "%local_ip%"=="" (
  FOR /F "tokens=3 delims=: " %%G IN ('netsh interface ip show address "Ethernet" ^| findstr "IP Address"') DO SET local_ip=%%G
)

IF "%local_ip%"=="" (
  echo Could not determine local IP address, using localhost
  SET local_ip=127.0.0.1
)

echo Using local IP address: %local_ip%
echo.

REM Get LM Studio server address
SET lm_studio_url=http://localhost:1234
IF "%1"=="" (
  echo Using default LM Studio URL: %lm_studio_url%
) ELSE (
  SET lm_studio_url=%1
  echo Using provided LM Studio URL: %lm_studio_url%
)

echo.
echo Starting server with validator... Press Ctrl+C to stop
python run_server.py --port=5000 --lm-url=%lm_studio_url%

echo Server stopped. 