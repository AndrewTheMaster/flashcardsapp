# Chinese Tutor API

Серверная часть приложения для изучения китайского языка, содержащая:
- API для генерации упражнений
- Валидатор содержимого на основе BERT-Chinese
- Многоязычный переводчик на основе Helsinki-NLP

## Настройка подключения к LM Studio в локальной сети

Для правильной работы с LM Studio в локальной сети следуйте этим рекомендациям:

1. **Правильный формат URL**: всегда используйте полный URL с указанием протокола, IP-адреса и порта:
   ```
   http://192.168.x.x:1234
   ```

2. **Проверка доступности**:
   - Убедитесь, что LM Studio запущен на целевом компьютере
   - Проверьте, что в настройках LM Studio включен API сервер (по умолчанию на порту 1234)
   - Проверьте сетевую доступность с помощью команды `ping 192.168.x.x`
   - Проверьте доступность TCP-порта с помощью скрипта test_connection.bat

3. **Брандмауэр**: при необходимости настройте правила брандмауэра для разрешения входящих подключений к порту LM Studio

4. **Запуск API сервера**:
   - При запуске run_server.bat введите полный URL к LM Studio
   - Используйте стандартный порт API сервера 5000 (можно изменить при запуске)

5. **Подключение мобильного приложения**:
   - Для эмулятора Android используйте адрес 10.0.2.2:5000
   - Для реальных устройств используйте локальный IP-адрес компьютера с API-сервером
   - Проверьте соединение в настройках приложения

## Диагностика проблем соединения

Если вы столкнулись с проблемами подключения к LM Studio, попробуйте следующее:

1. Запустите скрипт `test_connection.bat` с URL для проверки подключения
2. Проверьте доступность LM Studio с помощью команды ping и telnet:
   ```
   ping 192.168.x.x
   telnet 192.168.x.x 1234
   ```
3. Убедитесь, что в LM Studio открыта и загружена языковая модель
4. Проверьте API-запрос напрямую через браузер: `http://192.168.x.x:1234/v1/models`

## Запуск сервера

```bash
# Windows
.\run_server.bat

# Linux/Mac
./run_server.sh
```

## Тестирование компонентов

```bash
# Тестирование соединения с LM Studio
python run_server.py --test-lm

# Тестирование валидатора BERT
python run_server.py --test-bert

# Тестирование функции переводов
python run_server.py --test-translation
```

## Требования

- Python 3.8+
- Flask
- OpenAI API client
- PyTorch
- Transformers
- Дополнительные зависимости в requirements.txt

## Requirements

- Python 3.8+
- LM Studio running with gemma-3-4b-it-qat model (http://192.168.68.162:1234)
- Dependencies from requirements.txt

## Installation and Setup

1. Clone the repository
2. Create a virtual environment and install dependencies:
   ```
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```
3. Start LM Studio and load the gemma-3-4b-it-qat model
4. Run the API using one of the methods below

## Running the API

### Option 1: Using the Batch File (Recommended)

The easiest way to run the API is to use the batch file:

```
.\run_server.bat
```

This will present you with the following options:
1. Start API Server
2. Test BERT validator (server must be running)
3. Start server and test validator
4. Test LM Studio connection
5. Test Helsinki-NLP translation

### Option 2: Using Direct Python Commands

You can also run the server directly with various options:

```
# Start the server
python run_server.py

# Run the BERT validator test (server must be running separately)
python run_server.py --test-bert

# Test Helsinki-NLP translation models
python run_server.py --test-translation

# Start server in background and run validator test
python run_server.py --both

# Test LM Studio connection
python run_server.py --test-lm
```

## API Endpoints

### Generate Exercise `/generate`

**Method**: POST

**Request Body**:
```json
{
  "word": "服务器",
  "hsk_level": 4,
  "system_language": "ru",
  "validate": true,
  "retry_on_invalid": true
}
```

**Parameters**:
- `word`: Chinese word to generate an exercise for (required)
- `hsk_level`: HSK difficulty level from 1 to 9+ (default: 1)
- `system_language`: Language for translation (default: "ru")
- `validate`: Enable validation with BERT-Chinese-WWM (default: true)
- `retry_on_invalid`: Regenerate when validation fails (default: true)

**Response**:
```json
{
  "sentence_with_gap": "这个网站需要一个强大的 ____ 来保证流畅的体验。",
  "pinyin": "Zhè ge wǎngzhàn xūyào yī gè qiángdà de fúwùqì lái bǎozhèng liúchàng de tǐyàn.",
  "translation": "This website needs a powerful server to ensure a smooth experience.",
  "options": ["服务器", "电脑", "键盘", "鼠标"],
  "answer": "服务器",
  "validation": {
    "is_valid": true,
    "confidence": 0.85,
    "semantic_score": 0.92,
    "distractor_score": 0.74
  }
}
```

### Translation `/translate`

**Method**: POST

**Request Body**:
```json
{
  "text": "学习中文很有趣",
  "source_lang": "zh",
  "target_lang": "en",
  "need_pinyin": true
}
```

**Parameters**:
- `text`: Text to translate (required)
- `source_lang`: Source language code ("zh", "en", or "ru"). If omitted, language will be auto-detected.
- `target_lang`: Target language code ("zh", "en", or "ru") - required
- `need_pinyin`: Generate pinyin for Chinese text (default: true)

**Response**:
```json
{
  "original": "学习中文很有趣",
  "pinyin": "xué xí zhōng wén hěn yǒu qù",
  "english": "Learning Chinese is fun",
  "detected_language": "zh"
}
```

Supported translation directions:
- Chinese → English (direct)
- English → Chinese (direct)
- English → Russian (direct)
- Russian → English (direct)
- Chinese → Russian (via English)
- Russian → Chinese (via English)

### Check Connection `/test-connection`

**Method**: GET

**Response**:
```json
{
  "status": "success",
  "models": ["gemma-3-4b-it-qat"]
}
```

## Exercise Validation with BERT-Chinese-WWM

The API includes a validation system for generated exercises based on the BERT-Chinese-WWM model. The validator checks:

1. **Semantic coherence** - how well the correct answer fits the context
2. **Distractor quality** - whether wrong options are plausible but incorrect
3. **Gap placement optimization** - how well the gap is placed in the sentence

In API responses with validation enabled (`validate=true`), a `validation` field is included with these metrics:
- `is_valid`: overall validation result (true/false)
- `confidence`: validator confidence (0.0-1.0)
- `semantic_score`: semantic coherence score (0.0-1.0)
- `distractor_score`: distractor quality score (0.0-1.0)

If regeneration is enabled (`retry_on_invalid=true`), the API will automatically attempt to create a better exercise when validation scores are low, returning the result with the highest score.

## Translation with Helsinki-NLP Models

The API includes a bi-directional translation system based on Helsinki-NLP's Opus-MT models:

- **Direct translation**: Translates directly between language pairs with available models
- **Two-step translation**: For language pairs without direct models, translation happens via English
- **Pinyin generation**: Automatically generates pinyin for Chinese text
- **Language detection**: Can automatically detect the source language

The translator can fill in missing data in exercise generation when the LLM doesn't provide adequate translations or pinyin.

## Project Structure

- `app/validator.py` - Exercise validator using BERT-Chinese-WWM
- `app/translator.py` - Bi-directional translator using Helsinki-NLP models
- `run_server.py` - All-in-one server launcher and test script
- `run_server.bat` - Simple batch script to run the server

## Notes

- The API runs on port 5000 by default
- Ensure LM Studio is running and available at http://192.168.68.162:1234
- First validator run may take time to download the BERT-Chinese-WWM model
- First translator run will download Helsinki-NLP models as needed (each ~300MB) 