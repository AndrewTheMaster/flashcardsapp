"""
Server launcher script for Chinese Tutor API
Resolves import issues and ensures proper path configuration

Usage:
  python run_server.py               # Start the API server
  python run_server.py --test-bert   # Run validator test (server must be running separately)
  python run_server.py --test-translation # Run Helsinki-NLP translator test
  python run_server.py --both        # Start server and run validator test
  python run_server.py --test-lm     # Test LM Studio connection
  python run_server.py --port=5000   # Specify server port
  python run_server.py --lm-url=http://localhost:1234 # Specify LM Studio URL
"""
import os
import sys
import logging
import json
import time
import argparse
import subprocess
import threading
import socket
from flask import Flask, request, jsonify
from openai import OpenAI
import requests
import re

# Configure the script to run from the correct directory
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

# Import the validator directly from the app folder
sys.path.insert(0, os.path.join(script_dir, 'app'))
try:
    from validator import ContentValidator
    validator_enabled = True
except ImportError:
    print("Warning: Could not import ContentValidator. Validation will be disabled.")
    validator_enabled = False

# Import the translator
try:
    from translator import Translator
    translator_enabled = True
except ImportError:
    print("Warning: Could not import Translator. Translation will be disabled.")
    translator_enabled = False

# Initialize Flask app
app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG, 
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                   stream=sys.stdout)

# Default values that will be overridden by arguments
SERVER_PORT = int(os.environ.get("API_SERVER_PORT", 5000))
LM_STUDIO_URL = os.environ.get("LM_STUDIO_URL", "http://localhost:1234")

# Initialize OpenAI client for LM Studio
lm_client = None  # Will be initialized after parsing arguments

# Initialize validator if available
if validator_enabled:
    try:
        validator = ContentValidator()
        logging.info("Validator successfully initialized")
    except Exception as e:
        validator_enabled = False
        logging.error(f"Error initializing validator: {str(e)}")

# Initialize translator if available
if translator_enabled:
    try:
        translator = Translator()
        logging.info("Translator successfully initialized")
    except Exception as e:
        translator_enabled = False
        logging.error(f"Error initializing translator: {str(e)}")

# Function to initialize LM client with the current URL
def initialize_lm_client():
    global lm_client
    global LM_STUDIO_URL
    
    logging.info(f"Initializing connection to LM Studio at: {LM_STUDIO_URL}")
    
    # Проверка корректности URL
    if not LM_STUDIO_URL.startswith(("http://", "https://")):
        logging.error(f"Invalid URL format: {LM_STUDIO_URL}. URL must start with http:// or https://")
        return False
        
    # Отключаем все прокси
    os.environ["NO_PROXY"] = "*"
    os.environ["no_proxy"] = "*"
    if "HTTP_PROXY" in os.environ:
        del os.environ["HTTP_PROXY"]
    if "HTTPS_PROXY" in os.environ:
        del os.environ["HTTPS_PROXY"]
    if "http_proxy" in os.environ:
        del os.environ["http_proxy"]
    if "https_proxy" in os.environ:
        del os.environ["https_proxy"]
        
    # Проверяем доступность хоста
    try:
        import socket
        from urllib.parse import urlparse
        
        parsed_url = urlparse(LM_STUDIO_URL)
        host = parsed_url.netloc.split(':')[0]
        port = parsed_url.port or (443 if parsed_url.scheme == 'https' else 80)
        
        logging.info(f"Testing direct connectivity to {host}:{port}...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((host, port))
        sock.close()
        
        if result != 0:
            logging.error(f"Cannot connect directly to {host}:{port}. Network connectivity issue.")
            # Проверяем доступность хоста с помощью ping
            try:
                import subprocess
                logging.info(f"Trying to ping {host}...")
                ping_cmd = ["ping", "-n", "2", host]
                ping_result = subprocess.run(ping_cmd, capture_output=True, text=True)
                if ping_result.returncode == 0:
                    logging.info(f"Host {host} is reachable via ping, but port {port} is closed")
                else:
                    logging.error(f"Host {host} is not reachable via ping. Network issue.")
                logging.debug(f"Ping output: {ping_result.stdout}")
            except Exception as ping_error:
                logging.error(f"Error during ping check: {ping_error}")
            
            return False
        
        logging.info(f"Host {host}:{port} is directly reachable.")
    except Exception as e:
        logging.error(f"Error checking host connectivity: {e}")
        # Продолжим даже при ошибке проверки
    
    # Тестируем подключение к API LM Studio напрямую через requests
    try:
        import requests
        
        # Создаем сессию без прокси
        session = requests.Session()
        session.trust_env = False  # Игнорируем системные настройки прокси
        
        logging.info(f"Testing API using direct HTTP request to {LM_STUDIO_URL}/v1/models")
        
        response = session.get(f"{LM_STUDIO_URL}/v1/models", timeout=15)
        if response.status_code == 200:
            models_data = response.json().get("data", [])
            available_models = [model.get("id", "unknown") for model in models_data]
            logging.info(f"LM Studio connection successful. Available models: {available_models}")
            
            # Создаем клиент для OpenAI API с отключенными прокси
            import httpx
            http_client = httpx.Client(transport=httpx.HTTPTransport(proxy=None))
            
            # Инициализируем клиент OpenAI
            lm_client = OpenAI(
                base_url=f"{LM_STUDIO_URL}/v1",
                api_key="not-needed",
                timeout=30.0,
                max_retries=1,
                http_client=http_client
            )
            return True
        else:
            logging.error(f"HTTP request failed. Status: {response.status_code}, Response: {response.text}")
            
            # Пробуем получить информацию об ошибке
            try:
                error_data = response.json()
                logging.error(f"API error details: {error_data}")
            except:
                pass
                
            # Пробуем более специфичный запрос к API
            try:
                logging.info("Attempting alternative API test: sending a simple chat completion")
                payload = {
                    "model": "gemma-3-4b-it-qat",  # базовая модель
                    "messages": [
                        {"role": "user", "content": "Say hello in Chinese"}
                    ],
                    "max_tokens": 20
                }
                
                alt_response = session.post(
                    f"{LM_STUDIO_URL}/v1/chat/completions",
                    json=payload,
                    timeout=20
                )
                
                if alt_response.status_code == 200:
                    logging.info("Alternative API test successful")
                    # Создаем клиент OpenAI
                    import httpx
                    http_client = httpx.Client(transport=httpx.HTTPTransport(proxy=None))
                    lm_client = OpenAI(
                        base_url=f"{LM_STUDIO_URL}/v1",
                        api_key="not-needed",
                        timeout=30.0,
                        max_retries=1,
                        http_client=http_client
                    )
                    return True
                else:
                    logging.error(f"Alternative API test failed: {alt_response.status_code}")
                    return False
                    
            except Exception as alt_error:
                logging.error(f"Alternative API test failed: {alt_error}")
                return False
    except Exception as e:
        logging.error(f"Failed to initialize connection to LM Studio: {e}")
        lm_client = None
        return False

# Function to get local IP address for mobile connections
def get_local_ip():
    try:
        # Create a socket connection to a public address
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        logging.error(f"Error getting local IP: {e}")
        return "127.0.0.1"  # Fallback to localhost

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint that returns server status and available modules/models"""
    # Check LM Studio connection
    lm_studio_models = []
    lm_studio_enabled = False
    
    try:
        if lm_client is not None:
            # Attempt to get available models from LM Studio
            try:
                session = requests.Session()
                session.trust_env = False
                response = session.get(f"{LM_STUDIO_URL}/v1/models", timeout=3)
                if response.status_code == 200:
                    lm_studio_enabled = True
                    models_data = response.json()
                    if 'data' in models_data and isinstance(models_data['data'], list):
                        lm_studio_models = [model.get('id', 'unknown') for model in models_data['data']]
            except Exception as e:
                logging.warning(f"Error checking LM Studio models: {e}")
    except Exception as e:
        logging.error(f"Error in health check: {e}")
    
    return jsonify({
        "status": "ok",
        "server_time": time.time(),
        "translator_enabled": translator_enabled,
        "validator_enabled": validator_enabled,
        "lm_studio_enabled": lm_studio_enabled,
        "available_models": lm_studio_models,
        "server_info": {
            "api_version": "1.0.0",
            "server_port": SERVER_PORT,
            "lm_studio_url": LM_STUDIO_URL,
            "local_ip": get_local_ip()
        }
    })

@app.route('/test-connection', methods=['GET'])
def test_connection():
    """Test endpoint for checking connection to LM Studio"""
    try:
        if lm_client is None:
            logging.error("LM Studio client not initialized")
            return jsonify({
                "status": "error",
                "message": "LM Studio client not initialized",
                "connection": False
            }), 500
            
        # Попытка получить список моделей
        try:
            response = lm_client.models.list()
            return jsonify({
                "status": "success",
                "models": [model.id for model in response.data],
                "connection": True
            })
        except Exception as e:
            logging.error(f"Error connecting to LM Studio with OpenAI client: {str(e)}", exc_info=True)
            
            # Попробуем запасной вариант с прямым HTTP-запросом
            try:
                import requests
                response = requests.get(f"{LM_STUDIO_URL}/v1/models", timeout=5)
                if response.status_code == 200:
                    return jsonify({
                        "status": "success",
                        "models": [model.get("id") for model in response.json().get("data", [])],
                        "connection": True,
                        "note": "Connected via HTTP request (OpenAI client failed)"
                    })
                else:
                    return jsonify({
                        "status": "error",
                        "message": f"HTTP error: {response.status_code} - {response.text}",
                        "connection": False
                    }), 500
            except Exception as http_error:
                logging.error(f"HTTP fallback also failed: {str(http_error)}", exc_info=True)
                return jsonify({
                    "status": "error",
                    "message": f"Failed to connect to LM Studio: {str(e)}, HTTP fallback error: {str(http_error)}",
                    "connection": False
                }), 500
    except Exception as e:
        logging.error(f"Unexpected error in test-connection: {str(e)}", exc_info=True)
        return jsonify({
            "status": "error",
            "message": f"Unexpected error: {str(e)}",
            "connection": False
        }), 500

@app.route('/translate', methods=['POST'])
def translate_text():
    """Endpoint for translating text between Chinese, English, and Russian"""
    try:
        data = request.json
        logging.info(f"Translation request received: {data}")
        
        # Check if translator is available
        if not translator_enabled:
            return jsonify({
                "error": "Translator not initialized"
            }), 500
        
        # Get request parameters
        text = data.get('text', '').strip()
        source_lang = data.get('source_lang')  # Can be None for auto-detection
        target_lang = data.get('target_lang')
        need_pinyin = data.get('need_pinyin', True)
        
        # Check if text is present
        if not text:
            return jsonify({"error": "No text provided for translation"}), 400
            
        # Check if target language is provided
        if not target_lang:
            return jsonify({"error": "No target language provided"}), 400
            
        # Validate language codes
        valid_langs = ["zh", "en", "ru"]
        if source_lang and source_lang not in valid_langs:
            return jsonify({"error": f"Unsupported source language: {source_lang}"}), 400
            
        if target_lang not in valid_langs:
            return jsonify({"error": f"Unsupported target language: {target_lang}"}), 400
        
        # Perform translation
        result = translator.process_text(text, source_lang, target_lang, need_pinyin)
        
        return jsonify(result)
        
    except Exception as e:
        logging.error(f"Translation error: {str(e)}", exc_info=True)
        return jsonify({
            "error": f"Translation error: {str(e)}"
        }), 500

@app.route('/generate', methods=['POST'])
def generate_exercise():
    """Endpoint for generating exercises based on given Chinese word"""
    try:
        data = request.json
        logging.info(f"Request received: {data}")
        
        # Get parameters from request
        word = data.get('word')
        hsk_level = data.get('hsk_level', 1)
        system_language = data.get('system_language', 'ru')
        validate = data.get('validate', True)
        
        if not word:
            return jsonify({"error": "Word parameter (word) is missing"}), 400
        
        # Generate exercise
        result = generate_exercise_with_word(word, hsk_level, system_language)
        
        if 'error' in result:
            return jsonify(result), 500
            
        # Validate exercise if enabled
        if validate and validator_enabled:
            try:
                validation_result = validator.validate_exercise(result)
                
                # Add validation info to result
                result["validation"] = {
                    "is_valid": validation_result.get("is_valid", True),
                    "confidence": float(validation_result.get("confidence", 0.0)),
                    "semantic_score": float(validation_result.get("semantic_score", 0.0)),
                    "distractor_score": float(validation_result.get("distractor_score", 0.0))
                }
                
                # Подробное логирование результатов валидации
                validation_log = f"""
=== BERT-Chinese-WWM Validation Results ===
- Word: {word}
- Sentence: {result.get('sentence_with_gap', '')}
- Options: {result.get('options', [])}
- Is Valid: {validation_result.get('is_valid', True)}
- Confidence: {validation_result.get('confidence', 0.0):.4f}
- Semantic Score: {validation_result.get('semantic_score', 0.0):.4f}
- Distractor Score: {validation_result.get('distractor_score', 0.0):.4f}
======================================
"""
                logging.info(validation_log)
                
                # If validation fails, regenerate once
                if not validation_result.get("is_valid", True) and data.get('retry_on_invalid', True):
                    logging.warning(f"Validation failed for '{word}', trying to regenerate...")
                    retry_count = 1
                    max_retries = 3
                    while retry_count <= max_retries:
                        try:
                            # Regenerate with higher temperature for diversity
                            retry_result = generate_exercise_with_word(
                                word, hsk_level, system_language, temperature=0.9
                            )
                            
                            if 'error' not in retry_result:
                                # Validate regenerated exercise
                                retry_validation = validator.validate_exercise(retry_result)
                                retry_result["validation"] = {
                                    "is_valid": retry_validation.get("is_valid", True),
                                    "confidence": float(retry_validation.get("confidence", 0.0)),
                                    "semantic_score": float(retry_validation.get("semantic_score", 0.0)),
                                    "distractor_score": float(retry_validation.get("distractor_score", 0.0)),
                                    "is_retry": True
                                }
                                
                                # Use result with best confidence score
                                if retry_validation.get("confidence", 0.0) > validation_result.get("confidence", 0.0):
                                    result = retry_result
                                    logging.info("Using regenerated exercise with higher score")
                                    
                                    # Подробное логирование результатов повторной валидации
                                    retry_validation_log = f"""
=== REGENERATED BERT-Chinese-WWM Validation Results ===
- Word: {word}
- Sentence: {retry_result.get('sentence_with_gap', '')}
- Options: {retry_result.get('options', [])}
- Is Valid: {retry_validation.get('is_valid', True)}
- Confidence: {retry_validation.get('confidence', 0.0):.4f}
- Semantic Score: {retry_validation.get('semantic_score', 0.0):.4f}
- Distractor Score: {retry_validation.get('distractor_score', 0.0):.4f}
- IMPROVED: YES (using regenerated exercise)
"""
                                    if 'improvements' in retry_validation and retry_validation['improvements']:
                                        retry_validation_log += "- Suggestions for improvement:\n"
                                        for imp in retry_validation['improvements']:
                                            retry_validation_log += f"  * {imp}\n"
                                    
                                    logging.info(retry_validation_log)
                                else:
                                    # Если повторная генерация не дала улучшений, логируем это тоже
                                    logging.info(f"""
=== REGENERATED BERT-Chinese-WWM Validation Results ===
- Word: {word}
- Sentence: {retry_result.get('sentence_with_gap', '')}
- Options: {retry_result.get('options', [])}
- Is Valid: {retry_validation.get('is_valid', True)}
- Confidence: {retry_validation.get('confidence', 0.0):.4f}
- Semantic Score: {retry_validation.get('semantic_score', 0.0):.4f}
- Distractor Score: {retry_validation.get('distractor_score', 0.0):.4f}
- IMPROVED: NO (keeping original exercise)
""")
                                break
                        except Exception as e:
                            logging.error(f"Error during exercise generation for word '{word}': {e}")
                            if retry_count < max_retries:
                                retry_count += 1
                                logging.info(f"Retrying... (attempt {retry_count} of {max_retries})")
                                continue
                            else:
                                logging.warning(f"Failed to generate exercise after {max_retries} attempts, using fallback")
                                # Use a simple fallback exercise
                                result = {
                                    "sentence_with_gap": f"这是____{word}。", 
                                    "options": [word, "好", "人", "不"],
                                    "correctAnswer": word,
                                    "pinyin": pinyin.get_pinyin(f"这是{word}。"),
                                    "translation": "This is " + word + ".",
                                    "generated_with": "fallback",
                                    "validation": {
                                        "is_valid": True,
                                        "confidence": 0.5,
                                        "semantic_score": 0.5,
                                        "distractor_score": 0.5
                                    }
                                }
                                break
            except Exception as e:
                logging.error(f"Validation error: {str(e)}", exc_info=True)
                result["validation_error"] = str(e)
        
        return jsonify(result)
        
    except Exception as e:
        logging.error(f"Error: {str(e)}", exc_info=True)
        return jsonify({
            "status": "error",
            "message": "Internal server error"
        }), 500

def generate_exercise_with_word(word, hsk_level, system_language, temperature=0.7):
    """Generate exercise using the given word"""
    try:
        logging.info(f"Generating exercise for word: {word}, HSK: {hsk_level}, Language: {system_language}")
        
        # Create prompt for exercise generation
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
6. Обязательно включи поля: sentence_with_gap, pinyin, translation, options (массив из 4 элементов) и answer.

Формат возвращаемого JSON-ответа (соблюдай его точно):

{{
  "sentence_with_gap": "...",
  "pinyin": "...",
  "translation": "...",
  "options": ["...", "...", "...", "..."],
  "answer": "..."
}}"""
        
        # Проверим, инициализирован ли клиент LM Studio
        if lm_client is None:
            logging.error("LM Studio client is not initialized")
            logging.info("Trying to initialize LM Studio client")
            if not initialize_lm_client():
                logging.error("Failed to initialize LM Studio client. Using fallback approach.")
                return generate_exercise_fallback(word, hsk_level, system_language)
        
        # Пробуем прямой HTTP-запрос к LM Studio вместо OpenAI клиента
        try:
            import requests
            from requests.adapters import HTTPAdapter
            
            logging.info(f"Using direct HTTP request to {LM_STUDIO_URL}/v1/chat/completions")
            
            # Создаем сессию без прокси
            session = requests.Session()
            session.trust_env = False  # Игнорируем системные настройки прокси
            
            headers = {
                "Content-Type": "application/json"
            }
            
            # Улучшенный системный промпт с явными инструкциями по формату JSON
            system_prompt = """Ты помощник для изучения китайского языка. Твоя задача - создавать упражнения в формате JSON.

⚠️⚠️⚠️ КРИТИЧЕСКИ ВАЖНО: ⚠️⚠️⚠️
1. Возвращай ТОЛЬКО чистый валидный JSON, НЕ оборачивая его в тройные обратные кавычки.
2. НЕ используй никаких Markdown форматирований (```json, ``` и т.д.)
3. Используй ТОЛЬКО прямые двойные кавычки (") для ключей и значений JSON.
4. Убедись, что все ключи и строковые значения обрамлены двойными кавычками.
5. НЕ включай никакого вступительного или заключительного текста.
6. ТОЛЬКО JSON, ничего больше."""
            
            # Ограничиваем количество токенов для ускорения ответа
            payload = {
                "model": "gemma-3-4b-it-qat",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                "temperature": temperature,
                "max_tokens": 600,  # Уменьшаем для ускорения ответа
                "top_p": 0.95
            }
            
            # Пробуем несколько моделей
            models_to_try = ["gemma-3-4b-it-qat", "gemma-3-1b-it-qat", "gemma2-3-4b-it-qat", "gemma-2-7b-it-qat"]
            
            content = None
            used_model = None
            for model in models_to_try:
                try:
                    logging.info(f"Trying model: {model}")
                    payload["model"] = model
                    response = session.post(
                        f"{LM_STUDIO_URL}/v1/chat/completions",
                        headers=headers,
                        json=payload,
                        timeout=90  # Increased timeout for LM Studio
                    )
                    
                    if response.status_code == 200:
                        content = response.json()["choices"][0]["message"]["content"]
                        used_model = model
                        logging.info(f"Successfully generated exercise using model {model}")
                        break
                    else:
                        logging.error(f"HTTP request failed with status {response.status_code} for model {model}")
                except Exception as model_error:
                    logging.error(f"Error with model {model}: {model_error}")
                    continue
        except Exception as http_error:
            logging.error(f"All HTTP requests failed: {http_error}", exc_info=True)
            content = None
            used_model = None
        
        # Если не удалось получить ответ, используем запасной вариант
        if content is None:
            logging.error("Failed to generate exercise. Using fallback approach.")
            return generate_exercise_fallback(word, hsk_level, system_language)
        
        logging.info("Model response received successfully")
        logging.debug(f"Response: {content[:200]}...")
        
        # Extract JSON from model response
        result = extract_exercise_data(content, word)
        
        # Add information about the model used
        if used_model:
            result["generated_with"] = used_model
        
        # Try to supplement missing translation or pinyin using translator
        if translator_enabled and result:
            if not result.get("pinyin") or not result.get("translation"):
                chinese_sentence = result.get("sentence_with_gap", "").replace("____", word)
                if chinese_sentence:
                    # Get missing data from translator
                    logging.info("Supplementing data using translator")
                    
                    # Determine target language
                    target_lang = "en"
                    if system_language == "ru":
                        target_lang = "ru"
                    
                    trans_result = translator.process_text(
                        chinese_sentence, 
                        "zh", 
                        target_lang,
                        need_pinyin=True
                    )
                    
                    # Add missing data if needed
                    if not result.get("pinyin") and trans_result.get("pinyin"):
                        result["pinyin"] = trans_result["pinyin"]
                        logging.info("Added pinyin from translator")
                        
                    if not result.get("translation") and target_lang == "ru" and trans_result.get("russian"):
                        result["translation"] = trans_result["russian"]
                        logging.info("Added Russian translation from translator")
                    elif not result.get("translation") and target_lang == "en" and trans_result.get("english"):
                        result["translation"] = trans_result["english"]
                        logging.info("Added English translation from translator")
        
        return result
        
    except Exception as e:
        logging.error(f"Error generating exercise: {str(e)}", exc_info=True)
        return generate_exercise_fallback(word, hsk_level, system_language)

def generate_exercise_fallback(word, hsk_level, system_language):
    """Fallback method to generate a basic exercise when LM Studio is unavailable"""
    logging.info(f"Using fallback method to generate exercise for {word}")
    
    # Создаем базовый шаблон упражнения
    result = {
        "sentence_with_gap": f"这是一个使用{word}的____.  (Это предложение с использованием {word}.)",
        "options": [word, "选项2", "选项3", "选项4"],
        "answer": word,
        "pinyin": "",
        "translation": f"Это предложение с использованием {word}." if system_language == "ru" else f"This is a sentence using {word}."
    }
    
    # Если доступен переводчик, обогатим данные
    if translator_enabled:
        try:
            # Создадим простое предложение с этим словом
            sentence = f"我喜欢用{word}."  # "Мне нравится использовать [слово]."
            
            # Получаем пиньинь и перевод
            target_lang = "ru" if system_language == "ru" else "en"
            trans_result = translator.process_text(sentence, "zh", target_lang, need_pinyin=True)
            
            # Обновляем результат
            if trans_result.get("pinyin"):
                result["pinyin"] = trans_result["pinyin"]
                
            if target_lang == "ru" and trans_result.get("russian"):
                result["translation"] = trans_result["russian"]
            elif target_lang == "en" and trans_result.get("english"):
                result["translation"] = trans_result["english"]
                
            # Создаем предложение с пробелом
            result["sentence_with_gap"] = sentence.replace(word, "____")
            
            # Пытаемся найти 3 близких слова для вариантов
            # Это базовый вариант - в реальном применении нужно использовать 
            # семантически близкие слова из словаря
            common_words = ["东西", "事情", "学习", "工作", "时间", "问题", "地方", "方法"]
            options = [word]
            
            for common_word in common_words:
                if len(options) < 4 and common_word != word:
                    options.append(common_word)
            
            # Дополняем до 4 вариантов, если нужно
            while len(options) < 4:
                options.append(f"选项{len(options)}")
                
            result["options"] = options
            
        except Exception as trans_error:
            logging.error(f"Error in fallback translation: {trans_error}")
    
    result["note"] = "Generated using fallback method (limited LM Studio functionality)"
    return result

def extract_exercise_data(content, original_word):
    """Extract exercise data from model response"""
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

def safe_json_parse(json_str, original_word):
    """
    Улучшенный многоуровневый парсер JSON для надежного извлечения данных из ответов модели.
    
    Обрабатывает нестандартное форматирование, разные типы кавычек и поврежденные структуры JSON.
    В крайнем случае, создает минимально работоспособную структуру данных из текстового содержимого.
    """
    try:
        logging.info("Применяем улучшенный многоуровневый парсер JSON")
        
        # 1-й уровень: Нормализация и предварительная обработка строки
        # Нормализация кавычек
        json_str = json_str.replace('"', '"').replace('"', '"').replace('«', '"').replace('»', '"')
        json_str = json_str.replace(''', "'").replace(''', "'").replace('`', "'").replace('′', "'")
        
        # Удаление всех Markdown маркеров (в том числе вложенных блоков кода)
        json_str = re.sub(r'```[\w]*\s*|\s*```', '', json_str)
        
        # Удаление символов, которые могут помешать парсингу
        json_str = "".join(c for c in json_str if c.isprintable() or c.isspace())
        
        # 2-й уровень: Попытка извлечь полный JSON объект
        # Ищем самый внешний JSON объект
        matches = []
        brace_level = 0
        start_index = -1
        
        for i, char in enumerate(json_str):
            if char == '{':
                if brace_level == 0:
                    start_index = i
                brace_level += 1
            elif char == '}':
                brace_level -= 1
                if brace_level == 0 and start_index != -1:
                    matches.append(json_str[start_index:i+1])
        
        if matches:
            # Выбираем наиболее длинное и полное совпадение
            clean_json = max(matches, key=len)
            logging.debug(f"Найден JSON объект длиной {len(clean_json)} символов")
            
            # Исправляем часто встречающиеся проблемы синтаксиса JSON
            # Заменяем запятую после последнего элемента перед закрывающей скобкой
            clean_json = re.sub(r',(\s*[\]}])', r'\1', clean_json)
            # Исправляем пропущенные кавычки вокруг ключей
            clean_json = re.sub(r'(\{|\,)\s*([a-zA-Z0-9_]+)\s*:', r'\1"\2":', clean_json)
            
            # Попытка разбора через стандартный json.loads
            try:
                logging.debug("Попытка разбора JSON через json.loads")
                result = json.loads(clean_json)
                # Проверяем минимальную структуру
                if isinstance(result, dict):
                    # Добавим обязательные поля, если они отсутствуют
                    if "sentence_with_gap" not in result:
                        result["sentence_with_gap"] = f"这个句子中使用{original_word}。"
                        logging.debug("Добавлено базовое предложение")
                    
                    if "options" not in result or not isinstance(result["options"], list):
                        result["options"] = [original_word, "选项1", "选项2", "选项3"]
                        logging.debug("Добавлены базовые варианты")
                    elif original_word not in result["options"]:
                        result["options"][0] = original_word
                    
                    result["answer"] = original_word
                    
                    # Проверяем пропуск в предложении
                    if "____" not in result["sentence_with_gap"] and original_word in result["sentence_with_gap"]:
                        result["sentence_with_gap"] = result["sentence_with_gap"].replace(original_word, "____", 1)
                    
                    return result
            except json.JSONDecodeError as e:
                logging.warning(f"Не удалось разобрать JSON через стандартный парсер: {e}")
        
        # 3-й уровень: Извлечение полей с помощью регулярных выражений
        logging.info("Переход к извлечению полей через регулярные выражения")
        result = {}
        
        # Более гибкие шаблоны для поиска ключевых полей
        patterns = {
            "sentence_with_gap": r'["\']?sentence_with_gap["\']?\s*:\s*["\']([^"\']+)["\']',
            "pinyin": r'["\']?pinyin["\']?\s*:\s*["\']([^"\']+)["\']',
            "translation": r'["\']?translation["\']?\s*:\s*["\']([^"\']+)["\']',
            "answer": r'["\']?answer["\']?\s*:\s*["\']([^"\']+)["\']',
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, json_str)
            if match:
                result[key] = match.group(1)
                logging.debug(f"Найдено поле {key}: {result[key][:30]}...")
                
        # Особая обработка для массива options с поддержкой разных стилей кавычек
        options_match = re.search(r'["\']?options["\']?\s*:\s*\[(.*?)\]', json_str, re.DOTALL)
        if options_match:
            options_str = options_match.group(1)
            # Поддержка разных типов кавычек в массиве
            options = re.findall(r'["\']([^"\']+)["\']', options_str)
            if options:
                result["options"] = options
                logging.debug(f"Найдены варианты: {options}")
            
        # 4-й уровень: Текстовый анализ, если не получилось извлечь структуру
        if not result or "sentence_with_gap" not in result:
            logging.warning("Переходим к текстовому анализу неструктурированного контента")
            
            # Извлекаем китайские символы и предложения
            lines = json_str.split('\n')
            chinese_sentences = []
            
            # Сначала ищем готовые предложения
            for line in lines:
                line = line.strip()
                # Проверяем, содержит ли строка китайские символы
                if re.search(r'[\u4e00-\u9fff]', line):
                    chinese_sentences.append(line)
                    logging.debug(f"Найдено китайское предложение: {line}")
                
                # Ищем строки с определенными ключевыми словами
                if "sentence" in line.lower() or "example" in line.lower() or "句子" in line:
                    parts = line.split(":", 1)
                    if len(parts) > 1 and re.search(r'[\u4e00-\u9fff]', parts[1]):
                        chinese_sentences.append(parts[1].strip())
                
                # Записываем pinyin и translation если обнаружены
                if not result.get("pinyin") and ("pinyin" in line.lower() or "拼音" in line):
                    parts = line.split(":", 1)
                    if len(parts) > 1:
                        result["pinyin"] = parts[1].strip()
                
                if not result.get("translation") and ("translation" in line.lower() or "перевод" in line):
                    parts = line.split(":", 1)
                    if len(parts) > 1:
                        result["translation"] = parts[1].strip()
                
                # Собираем варианты ответов
                if line.startswith('-') or line.startswith('*') or line.startswith('•'):
                    option = line.strip('- *•').strip()
                    if option:
                        if "options" not in result:
                            result["options"] = []
                        if len(result["options"]) < 4 and option not in result["options"]:
                            result["options"].append(option)
            
            # Если нашли хотя бы одно китайское предложение, используем его
            if chinese_sentences:
                # Ищем предложение содержащее исходное слово или пробел
                for sentence in chinese_sentences:
                    if original_word in sentence:
                        result["sentence_with_gap"] = sentence.replace(original_word, "____", 1)
                        break
                    if "____" in sentence:
                        result["sentence_with_gap"] = sentence
                        break
                
                # Если не нашли предложения с пропуском, берем первое найденное
                if "sentence_with_gap" not in result:
                    result["sentence_with_gap"] = chinese_sentences[0]
                    # Если в предложении есть исходное слово, заменяем его на пропуск
                    if original_word in result["sentence_with_gap"]:
                        result["sentence_with_gap"] = result["sentence_with_gap"].replace(original_word, "____", 1)
                    else:
                        # Вставляем пробел в середину предложения
                        middle = len(result["sentence_with_gap"]) // 2
                        result["sentence_with_gap"] = (
                            result["sentence_with_gap"][:middle] + 
                            " ____ " + 
                            result["sentence_with_gap"][middle:]
                        )
            else:
                # Если нет ни одного китайского предложения, создаем базовое
                result["sentence_with_gap"] = f"请使用 ____ 造句。"
                logging.warning("Создано базовое предложение из-за отсутствия китайских предложений")
        
        # 5-й уровень: Финальное наполнение отсутствующих полей
        if "options" not in result or not result["options"]:
            result["options"] = [original_word]
            
        # Убедимся, что исходное слово в списке вариантов
        if original_word not in result["options"]:
            if len(result["options"]) >= 4:
                result["options"][0] = original_word
            else:
                result["options"].insert(0, original_word)
        
        # Дополняем до 4 вариантов, если нужно
        common_options = ["选项", "是的", "没有", "好的", "中国", "学习", "工作", "朋友"]
        i = 0
        while len(result["options"]) < 4:
            option = common_options[i % len(common_options)] + str(i + 1)
            if option not in result["options"]:
                result["options"].append(option)
            i += 1
        
        # Ограничиваем до 4 вариантов
        result["options"] = result["options"][:4]
        
        # Устанавливаем правильный ответ
        result["answer"] = original_word
        
        # Добавляем пустые поля, если они отсутствуют
        if "pinyin" not in result:
            result["pinyin"] = ""
            
        if "translation" not in result:
            result["translation"] = ""
        
        return result
    except Exception as e:
        # В случае полного краха создаем минимально работоспособную структуру
        logging.error(f"Ошибка в safe_json_parse: {str(e)}, возвращаем базовую структуру", exc_info=True)
        return {
            "sentence_with_gap": f"请使用 ____ 造句。",
            "pinyin": "",
            "translation": "",
            "options": [original_word, "选项1", "选项2", "选项3"],
            "answer": original_word,
            "fallback_reason": str(e)
        }

if __name__ == "__main__":
    # Setup command-line argument parser
    parser = argparse.ArgumentParser(description="Chinese Tutor API Server")
    parser.add_argument("--test-bert", action="store_true", help="Run BERT validator test")
    parser.add_argument("--test-translation", action="store_true", help="Run Helsinki-NLP translation test")
    parser.add_argument("--test-lm", action="store_true", help="Test LM Studio connection")
    parser.add_argument("--both", action="store_true", help="Start server and run tests")
    parser.add_argument("--port", type=int, help="Server port (default: 5000)")
    parser.add_argument("--lm-url", type=str, help="LM Studio URL (default: http://localhost:1234)")
    parser.add_argument("--enable-fallback", action="store_true", help="Enable fallback mode for exercise generation")
    
    args = parser.parse_args()
    
    # Override defaults with command line arguments if provided
    if args.port:
        SERVER_PORT = args.port
        print(f"Server port set to: {SERVER_PORT}")
        
    if args.lm_url:
        LM_STUDIO_URL = args.lm_url
        print(f"LM Studio URL set to: {LM_STUDIO_URL}")

    # Устанавливаем режим fallback, если указан соответствующий флаг
    ENABLE_FALLBACK = args.enable_fallback
    if ENABLE_FALLBACK:
        logging.info("Fallback mode enabled for exercise generation")

    # Initialize LM client with current settings
    lm_client_status = initialize_lm_client()
    if not lm_client_status:
        logging.warning("Failed to initialize LM client. Exercise generation functionality will be limited.")
        if not ENABLE_FALLBACK:
            logging.warning("Fallback mode not enabled - exercise generation may fail completely")
    
    # Get local IP for mobile device connections
    local_ip = get_local_ip()
    
    # Process args
    if args.test_lm:
        test_lm_studio_connection()
    elif args.test_bert:
        print("Running validator test (server must be running separately)...")
        test_validator()
    elif args.test_translation:
        print("Running Helsinki-NLP translation test...")
        # Run server in background if not already running
        try:
            requests.get(f"http://localhost:{SERVER_PORT}/test-connection", timeout=1)
            print("Server appears to be running already.")
        except:
            print("Starting server in background for translation tests...")
            server_thread = run_server_in_thread()
        
        test_translation()
    elif args.both:
        print("Starting server in background and running validator test...")
        server_thread = run_server_in_thread()
        test_validator()
        print("\nTests completed. Server is still running.")
        print("Press Ctrl+C to stop server.")
        try:
            # Keep main thread alive
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nStopping server...")
    else:
        # Default: just run the server
        print("\n=== Starting Chinese Tutor API Server ===")
        print(f"API will be available at:")
        print(f"- Local URL: http://localhost:{SERVER_PORT}")
        print(f"- Network URL: http://{local_ip}:{SERVER_PORT} (for mobile devices)")
        print(f"- LM Studio URL: {LM_STUDIO_URL}")
        print("\nTo use with mobile app:")
        print(f"1. Open the app and go to settings")
        print(f"2. Enter http://{local_ip}:{SERVER_PORT} as server address")
        print(f"3. Disable offline mode and test connection")
        print("\nPress Ctrl+C to stop server.")
        app.run(host='0.0.0.0', port=SERVER_PORT, threaded=True) 