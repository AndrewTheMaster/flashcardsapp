from flask import Flask, request, jsonify
from openai import OpenAI
from validator import ContentValidator, BertChineseValidator
from translator import Translator
import logging
import sys
import json
import time
import re
import threading
import uuid
from datetime import datetime
import queue

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG, 
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                   stream=sys.stdout)

# Увеличиваем таймаут для LM Studio до 90 секунд
lm_client = OpenAI(
    base_url="http://localhost:1234/v1",
    api_key="not-needed",
    timeout=90.0,
    http_client=None
)

# Инициализация валидатора упражнений с BERT-Chinese-WWM
try:
    validator = BertChineseValidator()
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

# Очередь для асинхронных задач генерации
task_queue = queue.Queue()
# Хранилище результатов выполнения задач
task_results = {}
# Максимальное время хранения результатов (5 минут)
RESULT_TTL = 300

# Запускаем обработчик задач в отдельном потоке
def task_worker():
    while True:
        try:
            task_id, word, hsk_level, system_language, temperature, validate, retry_on_invalid = task_queue.get()
            logging.info(f"Обработка задачи {task_id} для слова '{word}'")
            
            try:
                result = generate_exercise_with_gemma(word, hsk_level, system_language, temperature)
                
                # Если включена валидация
                if validate and validator_enabled and 'error' not in result:
                    try:
                        validation_result = validator.validate_exercise(result)
                        result["validation"] = {
                            "is_valid": validation_result.get("is_valid", True),
                            "confidence": validation_result.get("confidence", 0.0),
                            "semantic_score": validation_result.get("semantic_score", 0.0),
                            "distractor_score": validation_result.get("distractor_score", 0.0)
                        }
                        
                        # Повторная генерация если не прошло валидацию
                        if not validation_result.get("is_valid", True) and retry_on_invalid:
                            logging.warning(f"Упражнение для '{word}' не прошло валидацию, генерируем повторно")
                            retry_result = generate_exercise_with_gemma(word, hsk_level, system_language, 0.9)
                            
                            if 'error' not in retry_result:
                                retry_validation = validator.validate_exercise(retry_result)
                                retry_result["validation"] = {
                                    "is_valid": retry_validation.get("is_valid", True),
                                    "confidence": retry_validation.get("confidence", 0.0),
                                    "semantic_score": retry_validation.get("semantic_score", 0.0),
                                    "distractor_score": retry_validation.get("distractor_score", 0.0),
                                    "is_retry": True
                                }
                                
                                if retry_validation.get("confidence", 0.0) > validation_result.get("confidence", 0.0):
                                    result = retry_result
                                    logging.info("Используется повторно сгенерированное упражнение с более высокой оценкой")
                    except Exception as e:
                        logging.error(f"Ошибка валидации для задачи {task_id}: {str(e)}", exc_info=True)
                        result["validation_error"] = str(e)
                
                task_results[task_id] = {
                    "status": "completed",
                    "result": result,
                    "created_at": datetime.now().timestamp()
                }
                logging.info(f"Задача {task_id} успешно выполнена")
                
            except Exception as e:
                logging.error(f"Ошибка при генерации упражнения для задачи {task_id}: {str(e)}", exc_info=True)
                task_results[task_id] = {
                    "status": "error",
                    "error": str(e),
                    "created_at": datetime.now().timestamp()
                }
            
            # Отмечаем задачу как выполненную
            task_queue.task_done()
            
            # Очистка устаревших результатов
            current_time = datetime.now().timestamp()
            to_delete = []
            for tid, data in task_results.items():
                if current_time - data["created_at"] > RESULT_TTL:
                    to_delete.append(tid)
            
            for tid in to_delete:
                del task_results[tid]
                
        except Exception as e:
            logging.error(f"Ошибка в worker потоке: {str(e)}", exc_info=True)
            
# Запуск worker потока
worker_thread = threading.Thread(target=task_worker, daemon=True)
worker_thread.start()

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
        fast_response = data.get('fast_response', True)  # Быстрый ответ или ждать результат
        
        if not word:
            return jsonify({"error": "Не указано слово (параметр 'word')"}), 400
        
        # Для быстрого ответа используем асинхронную генерацию
        if fast_response:
            # Создаем ID задачи
            task_id = str(uuid.uuid4())
            
            # Добавляем задачу в очередь
            task_queue.put((task_id, word, hsk_level, system_language, 0.7, validate, data.get('retry_on_invalid', True)))
            
            # Возвращаем ID задачи для последующей проверки статуса
            return jsonify({
                "task_id": task_id,
                "status": "pending",
                "message": f"Задача генерации упражнения для '{word}' принята в обработку"
            })
        else:
            # Синхронная генерация (традиционный подход)
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

@app.route('/task/<task_id>', methods=['GET'])
def check_task_status(task_id):
    """Endpoint для проверки статуса асинхронной задачи"""
    if task_id not in task_results:
        return jsonify({
            "status": "pending",
            "message": "Задача все еще выполняется или не существует"
        })
    
    return jsonify(task_results[task_id])

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

⚠️ КРИТИЧЕСКИ ВАЖНЫЕ ТРЕБОВАНИЯ К ФОРМАТУ ОТВЕТА:

1. Ответ должен быть СТРОГО в формате JSON и НИЧЕГО кроме JSON.
2. JSON должен быть представлен напрямую, БЕЗ обёртывания в блоки кода (никаких ```json или ``` до или после).
3. Используй ТОЛЬКО стандартные прямые двойные кавычки (") для ключей и значений JSON.
4. НЕ используй фигурные кавычки, типографские кавычки или другие специальные символы в JSON.
5. НЕ добавляй пояснений, комментариев или любого другого текста до или после JSON.

Формат возвращаемого JSON-ответа (соблюдай его точно):
{{
  "sentence": "полное предложение с использованием слова",
  "sentence_with_gap": "предложение с пропуском ____",
  "options": ["вариант 1", "вариант 2", "вариант 3", "вариант 4"],
  "answer": "правильный вариант (оригинальное слово)",
  "pinyin": "полное предложение с пиньинем",
  "translation": "перевод предложения"
}}
"""
        
        # Улучшенный системный промпт с явными инструкциями по формату JSON
        system_prompt = """Ты помощник для изучения китайского языка. Твоя задача - создавать упражнения в формате JSON.

⚠️⚠️⚠️ КРИТИЧЕСКИ ВАЖНО: ⚠️⚠️⚠️
1. Возвращай ТОЛЬКО чистый валидный JSON, НЕ оборачивай его в тройные обратные кавычки.
2. НЕ используй никаких Markdown форматирований (```json, ``` и т.д.)
3. Используй ТОЛЬКО прямые двойные кавычки (") для ключей и значений JSON.
4. Убедись, что все ключи и строковые значения обрамлены двойными кавычками.
5. НЕ включай никакого вступительного или заключительного текста.
6. ТОЛЬКО JSON, ничего больше."""

        # Ограничиваем генерацию полезных токенов для ускорения
        max_tokens = 600
        
        # Попытка использовать более быстрые настройки генерации
        response = lm_client.chat.completions.create(
            model="LM Studio",  # В LM Studio это не имеет значения, т.к. модель уже загружена
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=temperature,
            max_tokens=max_tokens,
            top_p=0.95,
            frequency_penalty=0,
            presence_penalty=0
        )
        
        # Извлекаем сгенерированный контент
        content = response.choices[0].message.content
        logging.info("Ответ от модели получен успешно")
        logging.debug(f"Ответ: {content[:200]}...")
        
        # Извлекаем JSON из ответа
        return extract_exercise_data(content, word)
        
    except Exception as e:
        logging.error(f"Ошибка генерации упражнения: {str(e)}", exc_info=True)
        return {
            "error": f"Ошибка генерации: {str(e)}"
        }

def safe_json_parse(json_str, original_word):
    """
    Более надежный парсинг JSON строки с обработкой нестандартных кавычек и 
    возможностью извлечения ключевых полей с помощью регулярных выражений в случае ошибки.
    
    При необходимости создает структуру данных из текстового содержимого.
    """
    # Нормализация кавычек
    json_str = json_str.replace('"', '"').replace('"', '"')
    json_str = json_str.replace(''', "'").replace(''', "'")
    
    # Извлечение JSON с помощью регулярного выражения для более сложных случаев
    json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', json_str, re.DOTALL)
    if json_match:
        json_str = json_match.group(1)
    else:
        # Для обычного JSON без обертки
        json_match = re.search(r'(?:json)?\s*(\{.*?\})\s*', json_str, re.DOTALL)
        if json_match:
            json_str = json_match.group(1)
        
    try:
        # Попытка разбора через стандартный json.loads
        return json.loads(json_str)
    except json.JSONDecodeError:
        logging.warning("Не удалось разобрать JSON через стандартный парсер, извлекаем поля вручную")
        # Извлечение полей с помощью регулярных выражений
        result = {}
        patterns = {
            "sentence_with_gap": r'"sentence_with_gap"\s*:\s*"([^"]+)"',
            "pinyin": r'"pinyin"\s*:\s*"([^"]+)"',
            "translation": r'"translation"\s*:\s*"([^"]+)"',
            "answer": r'"answer"\s*:\s*"([^"]+)"',
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, json_str)
            if match:
                result[key] = match.group(1)
                
        # Особая обработка для массива options
        options_match = re.search(r'"options"\s*:\s*\[(.*?)\]', json_str)
        if options_match:
            options_str = options_match.group(1)
            options = re.findall(r'"([^"]+)"', options_str)
            result["options"] = options
            
        # Проверяем, что нам удалось что-то извлечь
        if result and len(result) >= 3:  # Если нашли хотя бы 3 поля
            # Убедимся, что оригинальное слово присутствует в options и answer
            if "options" not in result or not result["options"]:
                result["options"] = [original_word]
            elif original_word not in result["options"]:
                result["options"][0] = original_word
            
            result["answer"] = original_word
            return result
            
        # Если не удалось извлечь структуру через регулярки, пробуем текстовый анализ
        logging.warning("JSON не найден в ответе, создаем структуру данных вручную")
        
        # Ищем предложение с пропуском
        lines = json_str.split('\n')
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
            chinese_chars = ''.join([char for char in json_str if '\u4e00' <= char <= '\u9fff'])
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
            "raw_response": json_str
        }

def extract_exercise_data(content, original_word):
    """Извлечение данных упражнения из ответа модели"""
    try:
        # Логируем исходный контент для диагностики
        logging.debug(f"Original response content: {content[:200]}...")
        
        # 1. Более агрессивный поиск JSON в Markdown-блоке с учетом нескольких вариантов форматирования
        json_matches = re.findall(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', content, re.DOTALL)
        if json_matches:
            # Берем первое совпадение
            json_str = json_matches[0]
            logging.debug(f"Extracted JSON from code block: {json_str[:100]}...")
        else:
            # 2. Проверяем наличие "ленивого" Markdown без закрывающих обратных кавычек
            json_match = re.search(r'```(?:json)?\s*(\{[\s\S]*)', content, re.DOTALL)
            if json_match:
                json_str = json_match.group(1)
                # Ищем закрывающую скобку
                end_brace = json_str.rfind('}')
                if end_brace >= 0:
                    json_str = json_str[:end_brace+1]
                    logging.debug(f"Extracted JSON from incomplete Markdown block: {json_str[:100]}...")
            else:
                # 3. Стандартный способ поиска JSON, если блок Markdown не найден
                # Находим все пары фигурных скобок, а не только первую и последнюю
                matches = []
                # Сопоставляем открывающие и закрывающие скобки
                brace_level = 0
                start_index = -1
                
                for i, char in enumerate(content):
                    if char == '{':
                        if brace_level == 0:
                            start_index = i
                        brace_level += 1
                    elif char == '}':
                        brace_level -= 1
                        if brace_level == 0 and start_index != -1:
                            matches.append(content[start_index:i+1])
                
                if matches:
                    # Выбираем наиболее длинное и полное совпадение
                    json_str = max(matches, key=len)
                    logging.debug(f"Extracted raw JSON using braces matching: {json_str[:100]}...")
                else:
                    # 4. Если ничего не найдено, самый простой подход - поиск от { до }
                    json_start = content.find('{')
                    json_end = content.rfind('}') + 1
                    
                    if json_start >= 0 and json_end > json_start:
                        json_str = content[json_start:json_end]
                        logging.debug(f"Extracted raw JSON using simple search: {json_str[:100]}...")
                    else:
                        # 5. Если JSON не найден, пытаемся использовать safe_json_parse
                        logging.warning("JSON structure not found, trying safe_json_parse")
                        return safe_json_parse(content, original_word)
        
        # Заменяем неправильные кавычки на стандартные
        json_str = json_str.replace('"', '"').replace('"', '"').replace('«', '"').replace('»', '"')
        json_str = json_str.replace(''', "'").replace(''', "'").replace('`', "'").replace('′', "'")
        
        # Удаляем неразрывные пробелы и другие невидимые символы
        json_str = "".join(c for c in json_str if c.isprintable() or c.isspace())
        
        # Исправляем часто встречающиеся проблемы синтаксиса JSON
        # Заменяем запятую после последнего элемента перед закрывающей скобкой
        json_str = re.sub(r',(\s*[\]}])', r'\1', json_str)
        # Исправляем пропущенные кавычки вокруг ключей
        json_str = re.sub(r'(\{|\,)\s*([a-zA-Z0-9_]+)\s*:', r'\1"\2":', json_str)
        
        # Попытка разбора JSON
        try:
            exercise_data = json.loads(json_str)
        except json.JSONDecodeError as e:
            logging.error(f"JSON parse error: {e}, trying safe_json_parse")
            return safe_json_parse(json_str, original_word)
        
        # Проверяем наличие всех необходимых полей
        required_fields = ["sentence_with_gap", "pinyin", "translation", "options", "answer"]
        for field in required_fields:
            if field not in exercise_data:
                logging.warning(f"В ответе отсутствует поле '{field}', будет создано")
                # Создаем отсутствующие поля
                if field == "sentence_with_gap":
                    # Если есть предложение, используем его
                    if "sentence" in exercise_data:
                        exercise_data["sentence_with_gap"] = exercise_data["sentence"].replace(original_word, "____", 1)
                    else:
                        exercise_data["sentence_with_gap"] = f"这个句子中使用{original_word}。"
                elif field == "options":
                    exercise_data["options"] = [original_word, "选项1", "选项2", "选项3"]
                elif field == "answer":
                    exercise_data["answer"] = original_word
                elif field == "pinyin":
                    exercise_data["pinyin"] = ""  # Будет заполнено переводчиком позже
                elif field == "translation":
                    exercise_data["translation"] = ""  # Будет заполнено переводчиком позже
        
        # Убедимся, что оригинальное слово присутствует в вариантах ответа
        if not isinstance(exercise_data.get("options"), list):
            exercise_data["options"] = [original_word, "选项1", "选项2", "选项3"]
            logging.info("Создан новый список вариантов ответа")
        elif original_word not in exercise_data["options"]:
            exercise_data["options"][0] = original_word
            logging.info(f"Добавлено слово '{original_word}' в варианты ответов")
            
        # Проверим, что ответ совпадает с оригинальным словом
        if exercise_data.get("answer") != original_word:
            exercise_data["answer"] = original_word
            logging.info(f"Установлен правильный ответ: '{original_word}'")
        
        # Проверяем, есть ли пропуск ____ в предложении с пропуском
        if "sentence_with_gap" in exercise_data and "____" not in exercise_data["sentence_with_gap"]:
            # Если пропуска нет, то создаем его, заменяя оригинальное слово на ____
            # Используем более надежный метод замены
            sentence = exercise_data["sentence_with_gap"]
            if original_word in sentence:
                # Заменяем только первое вхождение слова
                exercise_data["sentence_with_gap"] = sentence.replace(original_word, "____", 1)
                logging.info(f"Добавлен пропуск в предложение: {exercise_data['sentence_with_gap']}")
            else:
                # Если слово не найдено в предложении, попробуем найти его в других вариантах
                logging.warning(f"Слово '{original_word}' не найдено в предложении, пробуем найти другие варианты")
                
                # Проверим, есть ли слово в других полях
                added_gap = False
                for option in exercise_data["options"]:
                    if option in sentence:
                        exercise_data["sentence_with_gap"] = sentence.replace(option, "____", 1)
                        logging.info(f"Добавлен пропуск для варианта '{option}': {exercise_data['sentence_with_gap']}")
                        added_gap = True
                        break
                
                # Если не удалось добавить пропуск, создаем простое предложение
                if not added_gap:
                    exercise_data["sentence_with_gap"] = f"请使用 ____ 造句。 ({original_word})"
                    logging.warning(f"Создано базовое предложение: {exercise_data['sentence_with_gap']}")
        
        return exercise_data
    except Exception as e:
        logging.error(f"Ошибка при извлечении данных упражнения: {str(e)}", exc_info=True)
        # В случае ошибки попробуем использовать safe_json_parse как последний вариант
        try:
            return safe_json_parse(content, original_word)
        except Exception as e2:
            logging.error(f"Safe JSON parse также не удался: {str(e2)}", exc_info=True)
            return {
                "error": f"Ошибка при извлечении данных упражнения: {str(e)}",
                "raw_response": content
            }

if __name__ == '__main__':
    logging.info("Запуск сервера на 0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, threaded=True) 