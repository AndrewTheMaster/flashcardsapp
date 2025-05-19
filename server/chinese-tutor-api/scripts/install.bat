@echo off
python -m venv venv
call venv\Scripts\activate
pip install -r requirements.txt

echo Запуск сервера на порту 5000...
start cmd /k "flask --app app/main run --host=0.0.0.0 --port=5000" 