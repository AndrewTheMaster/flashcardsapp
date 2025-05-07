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

# Удалить файлы моделей BERT
Write-Host "Removing BERT models and TFLite files..." -ForegroundColor Yellow
Get-ChildItem -Recurse -Path "." -Include "*.tflite", "*.bin", "*.model", "*.pb" | ForEach-Object {
    Write-Host "  Removing $_" -ForegroundColor Cyan
    Remove-Item -Force -Path $_.FullName
}

# Удалить временные файлы и кэш
Write-Host "Removing temp files and caches..." -ForegroundColor Yellow
Remove-Item -Recurse -Force -Path "temp" -ErrorAction SilentlyContinue
Remove-Item -Force -Path "*.log" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "android/.gradle" -ErrorAction SilentlyContinue

# Очистить проект Flutter
Write-Host "Cleaning Flutter project..." -ForegroundColor Yellow
flutter clean

Write-Host "Cleanup completed successfully!" -ForegroundColor Green 