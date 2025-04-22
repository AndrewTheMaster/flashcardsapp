Write-Host "Cleaning Flutter project..." -ForegroundColor Green

# Установка переменной окружения JAVA_HOME
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
Write-Host "JAVA_HOME set to: $env:JAVA_HOME" -ForegroundColor Cyan

# Очистка Flutter
Write-Host "Running flutter clean..." -ForegroundColor Yellow
flutter clean

# Удаление директорий сборки и кэша
$dirsToRemove = @(
    ".gradle",
    "build",
    ".dart_tool",
    "android/.gradle",
    "android/build",
    "ios/Pods",
    "ios/build"
)

foreach ($dir in $dirsToRemove) {
    if (Test-Path $dir) {
        Write-Host "Removing $dir..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
}

# Получение зависимостей
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

# Просмотр размера проекта
$size = 0
Get-ChildItem -Path . -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { $size += $_.Length }
$sizeInGB = [math]::Round($size / 1GB, 2)
$sizeInMB = [math]::Round($size / 1MB, 2)

Write-Host "Project cleaned successfully!" -ForegroundColor Green
Write-Host "Current project size: $sizeInGB GB ($sizeInMB MB)" -ForegroundColor Cyan 