# Chinese Flashcards - NLP-powered Chinese Language Learning App

*[English](#overview) | [Русский](#обзор)*

![Flutter](https://img.shields.io/badge/Flutter-3.29.3-blue)
![Dart](https://img.shields.io/badge/Dart-3.7.2-blue)
![Python](https://img.shields.io/badge/Python-3.10-green)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100.0-green)
![ChineseBERT](https://img.shields.io/badge/ChineseBERT-1.0-red)

## Overview

Chinese Flashcards is an innovative mobile application designed to help students learn Chinese through AI-generated "fill-in-the-blank" exercises created from authentic Chinese texts. The application leverages ChineseBERT, a specialized NLP model for Chinese language processing, to generate personalized learning content.

## Screenshots

<div align="center">
  <div style="display: flex; flex-direction: row; flex-wrap: wrap; justify-content: center; gap: 10px;">
    <img src="screenshots/main_screen.png" width="200" alt="Main Screen"/>
    <img src="screenshots/menu_screen.png" width="200" alt="Menu Screen"/>
    <img src="screenshots/memory_game_screen.png" width="200" alt="Memory Game"/>
    <img src="screenshots/generated_stuff_screen.png" width="200" alt="Generated Exercises"/>
  </div>
</div>

## Features

### Working Features
- **Cross-platform**: Works on both iOS and Android devices
- **Flashcard System**: Basic flashcard creation and review
- **Memory Game**: Interactive character matching game
- **User Profiles**: Basic user account system
- **Dark/Light Mode**: Adjustable application theme

### In Development
- **AI-generated exercises**: Creating "fill-in-the-blank" exercises using ChineseBERT
- **Personalized learning**: Difficulty adjustment based on user progress
- **Offline mode**: Practice without internet connection
- **Progress tracking**: Detailed learning statistics
- **Advanced Memory Games**: Additional games for improving character recognition

## Technologies Used
- **Frontend**: Flutter/Dart
- **Backend**: FastAPI (Python)
- **NLP Models**: ChineseBERT, Transformers
- **Database**: SQLite (local), PostgreSQL (server)
- **State Management**: Provider
- **Authentication**: Firebase Auth

## Installation

```bash
# Clone the repository
git clone https://github.com/AndrewTheMaster/flashcardsapp.git

# Navigate to the project directory
cd flashcardsapp

# Install dependencies
flutter pub get

# Run the application
flutter run
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

# Chinese Flashcards - приложение для изучения китайского с поддержкой NLP

*[English](#overview) | [Русский](#обзор)*

![Flutter](https://img.shields.io/badge/Flutter-3.29.3-blue)
![Dart](https://img.shields.io/badge/Dart-3.7.2-blue)
![Python](https://img.shields.io/badge/Python-3.10-green)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100.0-green)
![ChineseBERT](https://img.shields.io/badge/ChineseBERT-1.0-red)

## Обзор

Chinese Flashcards - это инновационное мобильное приложение, разработанное для помощи студентам в изучении китайского языка через упражнения "заполни пропуск", созданные с помощью ИИ на основе аутентичных китайских текстов. Приложение использует ChineseBERT, специализированную NLP-модель для обработки китайского языка, чтобы генерировать персонализированный учебный контент.

## Скриншоты

<div align="center">
  <div style="display: flex; flex-direction: row; flex-wrap: wrap; justify-content: center; gap: 10px;">
    <img src="screenshots/main_screen.png" width="200" alt="Главный экран"/>
    <img src="screenshots/menu_screen.png" width="200" alt="Экран меню"/>
    <img src="screenshots/memory_game_screen.png" width="200" alt="Игра на память"/>
    <img src="screenshots/generated_stuff_screen.png" width="200" alt="Сгенерированные упражнения"/>
  </div>
</div>

## Функции

### Работающие функции
- **Кроссплатформенность**: Работает на устройствах iOS и Android
- **Система флэш-карточек**: Базовое создание и просмотр карточек
- **Игра на память**: Интерактивная игра на сопоставление иероглифов
- **Профили пользователей**: Базовая система пользовательских аккаунтов
- **Темный/светлый режим**: Настраиваемая тема приложения

### В разработке
- **Упражнения, созданные ИИ**: Создание упражнений "заполни пропуск" с использованием ChineseBERT
- **Персонализированное обучение**: Настройка сложности в зависимости от прогресса пользователя
- **Офлайн-режим**: Возможность заниматься без подключения к интернету
- **Отслеживание прогресса**: Подробная статистика обучения
- **Продвинутые игры на запоминание**: Дополнительные игры для улучшения распознавания иероглифов

## Используемые технологии
- **Фронтенд**: Flutter/Dart
- **Бэкенд**: FastAPI (Python)
- **NLP-модели**: ChineseBERT, Transformers
- **База данных**: SQLite (локальная), PostgreSQL (серверная)
- **Управление состоянием**: Provider
- **Аутентификация**: Firebase Auth

## Установка

```bash
# Клонировать репозиторий
git clone https://github.com/AndrewTheMaster/flashcardsapp.git

# Перейти в директорию проекта
cd flashcardsapp

# Установить зависимости
flutter pub get

# Запустить приложение
flutter run
```

## Участие в разработке

Мы приветствуем вклад в развитие проекта! Пожалуйста, не стесняйтесь отправлять Pull Request.
