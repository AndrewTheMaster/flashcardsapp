# Скрипт для очистки проекта перед отправкой на GitHub

# Остановить скрипт при любой ошибке
$ErrorActionPreference = "Stop"

Write-Host "Starting cleanup process..." -ForegroundColor Green

# Удалить папки build в проекте
Write-Host "Removing build directories..." -ForegroundColor Yellow
Remove-Item -Recurse -Force -Path "build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "android/build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "android/app/build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "ios/build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path ".dart_tool" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path ".gradle" -ErrorAction SilentlyContinue

# Удаление виртуального окружения Python и кэша Python
Write-Host "Removing Python virtual environment and cache..." -ForegroundColor Yellow
Remove-Item -Recurse -Force -Path "server/chinese-tutor-api/venv" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "server/chinese-tutor-api/__pycache__" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "server/chinese-tutor-api/app/__pycache__" -ErrorAction SilentlyContinue
Get-ChildItem -Path "server" -Recurse -Filter "*.pyc" | ForEach-Object {
    Write-Host "  Removing $_" -ForegroundColor Cyan
    Remove-Item -Force -Path $_.FullName
}

# Удалить файлы моделей BERT
Write-Host "Removing BERT models and TFLite files..." -ForegroundColor Yellow
Get-ChildItem -Recurse -Path "." -Include "*.tflite", "*.bin", "*.model", "*.pb", "*.onnx" | ForEach-Object {
    Write-Host "  Removing $_" -ForegroundColor Cyan
    Remove-Item -Force -Path $_.FullName
}

# Удалить временные файлы и кэш
Write-Host "Removing temp files and caches..." -ForegroundColor Yellow
Remove-Item -Recurse -Force -Path "temp" -ErrorAction SilentlyContinue
Remove-Item -Force -Path "*.log" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "android/.gradle" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "server/chinese-tutor-api/models" -ErrorAction SilentlyContinue

# Очистить проект Flutter
Write-Host "Cleaning Flutter project..." -ForegroundColor Yellow
flutter clean

# Обновить .gitignore, если необходимо
if (-not (Select-String -Path ".gitignore" -SimpleMatch "venv/" -Quiet)) {
    Write-Host "Updating .gitignore to include venv directories..." -ForegroundColor Yellow
    Add-Content -Path ".gitignore" -Value "`n# Python virtual environments`nvenv/`n__pycache__/"
}

Write-Host "Cleanup completed successfully!" -ForegroundColor Green 