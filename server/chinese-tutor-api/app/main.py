from flask import Flask, request, jsonify
from openai import OpenAI
from validator import ContentValidator
from translator import Translator
import logging
import sys
import json
import time

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG, 
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                   stream=sys.stdout)

# Настройка клиента OpenAI для взаимодействия с LM Studio (Gemma3-IT-QAT)
lm_client = OpenAI(
    base_url="http://192.168.68.162:1234/v1",
    api_key="not-needed",
    timeout=60.0,
    http_client=None
)

# Инициализация валидатора упражнений с BERT-Chinese-WWM
try:
    validator = ContentValidator()
    validator_enabled = True
    logging.info("Валидатор упражнений BERT-Chinese-WWM успешно инициализирован")
except Exception as e:
    validator_enabled = False
    logging.error(f"Ошибка инициализации валидатора: {str(e)}")

# Инициализация переводчика с моделями Helsinki-NLP
try:
    translator = Translator()
    translator_enabled = True
    logging.info("Переводчик Helsinki-NLP успешно инициализирован")
except Exception as e:
    translator_enabled = False
    logging.error(f"Ошибка инициализации переводчика: {str(e)}")

@app.route('/test-connection', methods=['GET'])
def test_connection():
    """Тестовый endpoint для проверки подключения к LM Studio"""
    try:
        response = lm_client.models.list()
        return jsonify({
            "status": "success",
            "models": [model.id for model in response.data]
        })
    except Exception as e:
        logging.error(f"Ошибка при подключении к LM Studio: {str(e)}", exc_info=True)
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route('/translate', methods=['POST'])
def translate_text():
    """Endpoint для перевода текста с поддержкой китайского, русского и английского языков"""
    try:
        data = request.json
        logging.info(f"Получен запрос на перевод: {data}")
        
        # Проверка наличия переводчика
        if not translator_enabled:
            return jsonify({
                "error": "Переводчик не инициализирован"
            }), 500
        
        # Получаем параметры запроса
        text = data.get('text', '').strip()
        source_lang = data.get('source_lang')  # Может быть None для автоопределения
        target_lang = data.get('target_lang')
        need_pinyin = data.get('need_pinyin', True)
        use_helsinki = data.get('use_helsinki', False)  # Параметр для выбора переводчика
        
        # Проверяем наличие текста
        if not text:
            return jsonify({"error": "Отсутствует текст для перевода"}), 400
            
        # Проверяем наличие целевого языка
        if not target_lang:
            return jsonify({"error": "Не указан целевой язык перевода"}), 400
            
        # Валидация языковых кодов
        valid_langs = ["zh", "en", "ru"]
        if source_lang and source_lang not in valid_langs:
            return jsonify({"error": f"Неподдерживаемый исходный язык: {source_lang}"}), 400
            
        if target_lang not in valid_langs:
            return jsonify({"error": f"Неподдерживаемый целевой язык: {target_lang}"}), 400
        
        # Если выбран перевод Helsinki, используем модель
        if use_helsinki:
            result = translator.process_text(text, source_lang, target_lang, need_pinyin)
        else:
            # Иначе возвращаем оригинальный текст без перевода
            result = {"original": text, "error": "Перевод не выполнен, параметр use_helsinki=false"}
        
        return jsonify(result)
        
    except Exception as e:
        logging.error(f"Ошибка при переводе: {str(e)}", exc_info=True)
        return jsonify({
            "error": f"Ошибка перевода: {str(e)}"
        }), 500

@app.route('/generate', methods=['POST'])
def generate_exercise():
    """Endpoint для генерации упражнений на основе заданного китайского слова"""
    try:
        data = request.json
        logging.info(f"Получен запрос: {data}")
        
        # Получаем параметры из запроса
        word = data.get('word')
        hsk_level = data.get('hsk_level', 1)
        system_language = data.get('system_language', 'ru')
        validate = data.get('validate', True)  # По умолчанию включена валидация
        
        if not word:
            return jsonify({"error": "Не указано слово (параметр 'word')"}), 400
        
        # Генерация упражнения с использованием Gemma3-IT-QAT через LM Studio
        result = generate_exercise_with_gemma(word, hsk_level, system_language)
        
        if 'error' in result:
            return jsonify(result), 500
            
        # Валидация упражнения с помощью BERT-Chinese-WWM, если включена
        if validate and validator_enabled:
            try:
                validation_result = validator.validate_exercise(result)
                
                # Добавляем информацию о валидации к результату
                result["validation"] = {
                    "is_valid": validation_result.get("is_valid", True),
                    "confidence": validation_result.get("confidence", 0.0),
                    "semantic_score": validation_result.get("semantic_score", 0.0),
                    "distractor_score": validation_result.get("distractor_score", 0.0)
                }
                
                # Если упражнение не прошло валидацию, попробуем сгенерировать еще раз
                if not validation_result.get("is_valid", True) and data.get('retry_on_invalid', True):
                    logging.warning(f"Упражнение не прошло валидацию: {validation_result}")
                    
                    # Добавляем информацию о том, что генерируем повторно
                    result["note"] = "Первый вариант упражнения не прошел валидацию, генерируем повторно"
                    
                    # Повторная генерация с более высокой температурой для разнообразия
                    retry_result = generate_exercise_with_gemma(
                        word, hsk_level, system_language, temperature=0.9
                    )
                    
                    if 'error' not in retry_result:
                        # Валидируем повторную генерацию
                        retry_validation = validator.validate_exercise(retry_result)
                        retry_result["validation"] = {
                            "is_valid": retry_validation.get("is_valid", True),
                            "confidence": retry_validation.get("confidence", 0.0),
                            "semantic_score": retry_validation.get("semantic_score", 0.0),
                            "distractor_score": retry_validation.get("distractor_score", 0.0),
                            "is_retry": True
                        }
                        
                        # Используем результат с лучшей оценкой
                        if retry_validation.get("confidence", 0.0) > validation_result.get("confidence", 0.0):
                            result = retry_result
                            logging.info("Используется повторно сгенерированное упражнение с более высокой оценкой")
                        
            except Exception as e:
                logging.error(f"Ошибка валидации: {str(e)}", exc_info=True)
                result["validation_error"] = str(e)
        
        return jsonify(result)
        
    except Exception as e:
        logging.error(f"Ошибка: {str(e)}", exc_info=True)
        return jsonify({
            "status": "error",
            "message": "Внутренняя ошибка сервера"
        }), 500

def generate_exercise_with_gemma(word, hsk_level, system_language, temperature=0.7):
    """Генерация упражнения с использованием Gemma3-IT-QAT через LM Studio"""
    try:
        logging.info(f"Генерация упражнения для слова: {word}, HSK: {hsk_level}, Язык: {system_language}")
        
        # Формируем промпт для генерации упражнения
        user_prompt = f"""Ты генератор учебных упражнений по китайскому языку. Вот твоя задача:

На вход ты получаешь:
- одно китайское слово: {word}
- уровень сложности HSK (от 1 до 9+): {hsk_level}
- системный язык пользователя: {system_language}

Генерируй упражнение по следующей структуре:

1. Составь одно естественное китайское предложение, в котором органично используется это слово. Тематика — на твоё усмотрение.
2. Сделай версию этого же предложения с пропущенным словом (замени слово на '____').
3. Предложи четыре варианта ответа: один правильный (то самое слово) и три лексически близких, но по смыслу в этом предложении неподходящих.
4. Приведи полную версию предложения с пиньинем.
5. Приведи перевод предложения на {system_language}.

Формат возвращаемого JSON-ответа:
{{
  "sentence": "полное предложение с использованием слова",
  "sentence_with_gap": "предложение с пропуском ____",
  "options": ["вариант 1", "вариант 2", "вариант 3", "вариант 4"],
  "answer": "правильный вариант (оригинальное слово)",
  "pinyin": "полное предложение с пиньинем",
  "translation": "перевод предложения"
}}
"""
        
        # Отправляем запрос в LM Studio для генерации с помощью Gemma3-IT-QAT
        response = lm_client.chat.completions.create(
            model="LM Studio",  # В LM Studio это не имеет значения, т.к. модель уже загружена
            messages=[
                {"role": "system", "content": "Ты помощник для изучения китайского языка. Ты отвечаешь на языке пользователя и следуешь его инструкциям точно."},
                {"role": "user", "content": user_prompt}
            ],
            temperature=temperature,
            max_tokens=1000,
            top_p=0.95,
            frequency_penalty=0,
            presence_penalty=0
        )
        
        # Извлекаем сгенерированный контент
        content = response.choices[0].message.content
        logging.info(f"Сгенерированный контент: {content}")
        
        # Извлекаем JSON из ответа
        return extract_exercise_data(content, word)
        
    except Exception as e:
        logging.error(f"Ошибка генерации упражнения: {str(e)}", exc_info=True)
        return {
            "error": f"Ошибка генерации: {str(e)}"
        }

def extract_exercise_data(content, original_word):
    """Извлечение данных упражнения из ответа модели"""
    try:
        # Пытаемся найти JSON в ответе
        json_start = content.find('{')
        json_end = content.rfind('}') + 1
        
        if json_start >= 0 and json_end > json_start:
            json_str = content[json_start:json_end]
            exercise_data = json.loads(json_str)
            
            # Проверяем наличие всех необходимых полей
            required_fields = ["sentence_with_gap", "pinyin", "translation", "options", "answer"]
            for field in required_fields:
                if field not in exercise_data:
                    raise ValueError(f"В ответе отсутствует поле '{field}'")
            
            # Убедимся, что оригинальное слово присутствует в вариантах ответа
            if original_word not in exercise_data["options"]:
                exercise_data["options"][0] = original_word
                
            # Проверим, что ответ совпадает с оригинальным словом
            if exercise_data["answer"] != original_word:
                exercise_data["answer"] = original_word
            
            # Проверяем, есть ли пропуск ____ в предложении с пропуском
            if "____" not in exercise_data["sentence_with_gap"]:
                # Если пропуска нет, то создаем его, заменяя оригинальное слово на ____
                # Используем более надежный метод замены
                sentence = exercise_data["sentence_with_gap"]
                if original_word in sentence:
                    # Заменяем только первое вхождение слова
                    exercise_data["sentence_with_gap"] = sentence.replace(original_word, "____", 1)
                    logging.info(f"Добавлен пропуск в предложение: {exercise_data['sentence_with_gap']}")
                else:
                    # Если слово не найдено в предложении, попробуем найти его в пиньине
                    logging.warning(f"Слово '{original_word}' не найдено в предложении, пробуем найти другие варианты")
                    
                    # Проверим, есть ли слово в других полях
                    for option in exercise_data["options"]:
                        if option in sentence:
                            exercise_data["sentence_with_gap"] = sentence.replace(option, "____", 1)
                            logging.info(f"Добавлен пропуск для варианта '{option}': {exercise_data['sentence_with_gap']}")
                            break
            
            return exercise_data
        else:
            # Если JSON не найден, создаем простую структуру данных
            logging.warning("JSON не найден в ответе, создаем структуру данных вручную")
            
            # Ищем предложение с пропуском
            lines = content.split('\n')
            sentence_with_gap = ""
            pinyin = ""
            translation = ""
            options = [original_word]
            
            for line in lines:
                line = line.strip()
                if "____" in line:
                    sentence_with_gap = line
                elif "pinyin" in line.lower() or "拼音" in line:
                    pinyin = line.split(":", 1)[1].strip() if ":" in line else line
                elif "translation" in line.lower() or "перевод" in line.lower():
                    translation = line.split(":", 1)[1].strip() if ":" in line else line
                elif line.startswith('-') or line.startswith('*'):
                    option = line.strip('- *').strip()
                    if option and option != original_word and len(options) < 4:
                        options.append(option)
            
            # Если нужных данных нет, берем все китайские символы из ответа
            if not sentence_with_gap:
                chinese_chars = ''.join([char for char in content if '\u4e00' <= char <= '\u9fff'])
                if chinese_chars:
                    halfway = len(chinese_chars) // 2
                    sentence_with_gap = chinese_chars[:halfway] + " ____ " + chinese_chars[halfway:]
            
            # Добавляем недостающие варианты ответов
            while len(options) < 4:
                options.append(f"选项{len(options)}")
                
            return {
                "sentence_with_gap": sentence_with_gap,
                "pinyin": pinyin,
                "translation": translation,
                "options": options,
                "answer": original_word
            }
                
    except Exception as e:
        logging.error(f"Ошибка при извлечении данных упражнения: {str(e)}", exc_info=True)
        return {
            "error": f"Ошибка при извлечении данных упражнения: {str(e)}",
            "raw_response": content
        }

if __name__ == '__main__':
    logging.info("Запуск сервера на 0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, threaded=True) 