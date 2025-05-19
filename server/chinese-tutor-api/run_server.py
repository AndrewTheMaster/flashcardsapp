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

Формат возвращаемого JSON-ответа:

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
            
            payload = {
                "model": "gemma-3-4b-it-qat",
                "messages": [{"role": "user", "content": user_prompt}],
                "temperature": temperature,
                "max_tokens": 800
            }
            
            # Пробуем несколько моделей
            models_to_try = ["gemma-3-4b-it-qat", "gemma2-3-4b-it-qat", "gemma-2-7b-it-qat", "llama-7b-chat", "mistral-7b-instruct-v0.2"]
            
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
                        timeout=80  # Increased timeout for LM Studio
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
        logging.debug(f"Response: {content}")
        
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
        # Try to find JSON in response
        json_start = content.find('{')
        json_end = content.rfind('}') + 1
        
        if json_start >= 0 and json_end > json_start:
            json_str = content[json_start:json_end]
            exercise_data = json.loads(json_str)
            
            # Check for required fields
            required_fields = ["sentence_with_gap", "pinyin", "translation", "options", "answer"]
            for field in required_fields:
                if field not in exercise_data:
                    raise ValueError(f"Field '{field}' missing in response")
            
            # Ensure correct word is in options
            if original_word not in exercise_data["options"]:
                exercise_data["options"][0] = original_word
                
            # Ensure answer matches original word
            if exercise_data["answer"] != original_word:
                exercise_data["answer"] = original_word
            
            # Check for ____ placeholder in sentence with gap
            if "____" not in exercise_data["sentence_with_gap"]:
                # Add placeholder if missing
                sentence = exercise_data["sentence_with_gap"]
                if original_word in sentence:
                    # Replace only first occurrence
                    exercise_data["sentence_with_gap"] = sentence.replace(original_word, "____", 1)
                    logging.info(f"Added gap placeholder to sentence: {exercise_data['sentence_with_gap']}")
                else:
                    # Try finding word in other options if original not found
                    logging.warning(f"Word '{original_word}' not found in sentence, trying alternatives")
                    
                    # Check for word in other fields
                    for option in exercise_data["options"]:
                        if option in sentence:
                            exercise_data["sentence_with_gap"] = sentence.replace(option, "____", 1)
                            logging.info(f"Added gap for option '{option}': {exercise_data['sentence_with_gap']}")
                            break
            
            return exercise_data
        else:
            # If JSON not found, create basic data structure
            logging.warning("JSON not found in response, creating manual structure")
            
            # Look for sentence with gap
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
            
            # If no sentence with gap found, extract Chinese characters
            if not sentence_with_gap:
                chinese_chars = ''.join([char for char in content if '\u4e00' <= char <= '\u9fff'])
                if chinese_chars:
                    halfway = len(chinese_chars) // 2
                    sentence_with_gap = chinese_chars[:halfway] + " ____ " + chinese_chars[halfway:]
            
            # Add missing options
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
        logging.error(f"Error extracting exercise data: {str(e)}", exc_info=True)
        return {
            "error": f"Error extracting exercise data: {str(e)}",
            "raw_response": content
        }

def test_validator():
    """Run validator test against a running server"""
    print("\n=== BERT Validator Test ===")
    
    # Disable any proxy settings
    os.environ['NO_PROXY'] = 'localhost,127.0.0.1'
    
    # Test words
    test_words = [
        {"word": "服务器", "hsk_level": 4, "system_language": "ru", "validate": True},
        {"word": "银行", "hsk_level": 2, "system_language": "en", "validate": True},
        {"word": "电脑", "hsk_level": 3, "system_language": "en", "validate": True}
    ]
    
    # API URL - make sure we're using the correct port
    api_url = f"http://localhost:{SERVER_PORT}/generate"
    print(f"Sending requests to: {api_url}")
    
    for test_case in test_words:
        print(f"\nTesting word: {test_case['word']} (HSK {test_case['hsk_level']}, Lang: {test_case['system_language']})")
        
        try:
            # Create a session without proxy
            session = requests.Session()
            session.trust_env = False  # Don't use any proxy settings from environment
            
            # Make the request
            print(f"Making direct request to {api_url}...")
            response = session.post(
                api_url,
                json=test_case,
                timeout=120
            )
            
            # Check response
            if response.status_code != 200:
                print(f"Error: API returned status code {response.status_code}")
                print(f"Response: {response.text}")
                continue
                
            # Parse result
            result = response.json()
            
            # Display basic information
            print("\nBasic Info:")
            print(f"Sentence with gap: {result.get('sentence_with_gap', '')}")
            print(f"Pinyin: {result.get('pinyin', '')}")
            print(f"Translation: {result.get('translation', '')}")
            print(f"Options: {', '.join(result.get('options', []))}")
            print(f"Answer: {result.get('answer', '')}")
            
            # Display validation results
            if 'validation' in result:
                validation = result['validation']
                print("\nBERT-WWM VALIDATION RESULTS:")
                print(f"Valid: {'✓' if validation.get('is_valid', False) else '✗'}")
                print(f"Confidence: {validation.get('confidence', 0.0):.4f}")
                print(f"Semantic score: {validation.get('semantic_score', 0.0):.4f}")
                print(f"Distractor score: {validation.get('distractor_score', 0.0):.4f}")
                
                if validation.get('is_retry', False):
                    print("⚠ This is a regeneration after failed validation")
                    
                if 'improvements' in validation and validation['improvements']:
                    print("\nImprovement suggestions:")
                    for imp in validation['improvements']:
                        print(f"- {imp}")
            else:
                print("\n⚠ Validation not performed or failed")
                if 'validation_error' in result:
                    print(f"Validation error: {result['validation_error']}")
                
        except Exception as e:
            print(f"Error during test: {str(e)}")
            import traceback
            print(traceback.format_exc())
            
        print("\n" + "-"*50)
    
    print("\nValidator test completed!")

def test_translation():
    """Run translation test for Helsinki-NLP models"""
    print("\n=== Helsinki-NLP Translation Test ===")
    
    if not translator_enabled:
        print("\n❌ Translator not enabled. Cannot perform test.")
        return
        
    # Test directly with the translator class
    print("\nDirect translation tests:")
    try:
        # Test Chinese to English
        zh_text = "我喜欢学习中文和编程"
        print(f"\nChinese to English: '{zh_text}'")
        en_result = translator.translate(zh_text, "zh", "en")
        print(f"Result: '{en_result}'")
        
        # Test English to Russian
        en_text = "I enjoy learning Chinese and programming"
        print(f"\nEnglish to Russian: '{en_text}'")
        ru_result = translator.translate(en_text, "en", "ru")
        print(f"Result: '{ru_result}'")
        
        # Test Russian to English
        ru_text = "Я люблю изучать китайский язык и программирование"
        print(f"\nRussian to English: '{ru_text}'")
        en_result = translator.translate(ru_text, "ru", "en")
        print(f"Result: '{en_result}'")
        
        # Test English to Chinese
        en_text = "The weather is nice today"
        print(f"\nEnglish to Chinese: '{en_text}'")
        zh_result = translator.translate(en_text, "en", "zh")
        print(f"Result: '{zh_result}'")
        
        # Test complete processing for bi-directional translation
        print("\nTesting complete bi-directional processing:")
        
        # Chinese text with pinyin
        zh_text = "学习外语很有趣"
        print(f"\nChinese text: '{zh_text}'")
        result = translator.process_text(zh_text, "zh", "en", need_pinyin=True)
        print("Result:")
        print(f"- Original: {result.get('original', '')}")
        print(f"- Pinyin: {result.get('pinyin', '')}")
        print(f"- English: {result.get('english', '')}")
        if 'russian' in result:
            print(f"- Russian: {result.get('russian', '')}")
            
        # English text to Chinese with pinyin
        en_text = "Learning foreign languages is interesting"
        print(f"\nEnglish text: '{en_text}'")
        result = translator.process_text(en_text, "en", "zh", need_pinyin=True)
        print("Result:")
        print(f"- Original: {result.get('original', '')}")
        print(f"- Chinese: {result.get('chinese', '')}")
        print(f"- Pinyin: {result.get('pinyin', '')}")
        
        # Russian text to Chinese with pinyin
        ru_text = "Изучение иностранных языков интересно"
        print(f"\nRussian text: '{ru_text}'")
        result = translator.process_text(ru_text, "ru", "zh", need_pinyin=True)
        print("Result:")
        print(f"- Original: {result.get('original', '')}")
        print(f"- English: {result.get('english', '')}")
        print(f"- Chinese: {result.get('chinese', '')}")
        print(f"- Pinyin: {result.get('pinyin', '')}")
        
    except Exception as e:
        print(f"\n❌ Error during translation test: {str(e)}")
        
    # Test through the API
    print("\nAPI translation tests:")
    import requests
    
    # Test cases
    test_cases = [
        {"text": "学习中文很有趣", "source_lang": "zh", "target_lang": "en", "need_pinyin": True},
        {"text": "Learning Chinese is fun", "source_lang": "en", "target_lang": "ru", "need_pinyin": False},
        {"text": "Изучение китайского языка увлекательно", "source_lang": "ru", "target_lang": "zh", "need_pinyin": True},
    ]
    
    # API URL
    api_url = f"http://localhost:{SERVER_PORT}/translate"
    
    for i, test_case in enumerate(test_cases):
        print(f"\n{i+1}. Testing: {test_case['text'][:30]}... ({test_case['source_lang']} to {test_case['target_lang']})")
        
        try:
            response = requests.post(
                api_url,
                json=test_case,
                timeout=60
            )
            
            # Check response
            if response.status_code != 200:
                print(f"Error: API returned status code {response.status_code}")
                print(f"Response: {response.text}")
                continue
                
            # Parse result
            result = response.json()
            
            # Display result
            print("\nTranslation result:")
            for key, value in result.items():
                if key != "detected_language":
                    print(f"{key}: {value}")
                
        except Exception as e:
            print(f"Error during API test: {str(e)}")
            
        print("\n" + "-"*30)
    
    print("\nTranslation test completed!")

def test_lm_studio_connection():
    """Test connection to LM Studio"""
    print("\n=== LM Studio Connection Test ===")
    
    try:
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
            
        # Попытка через requests
        import requests
        session = requests.Session()
        session.trust_env = False  # Игнорируем системные настройки прокси
        print(f"Testing API using direct HTTP request to {LM_STUDIO_URL}/v1/models...")
        
        response = session.get(f"{LM_STUDIO_URL}/v1/models", timeout=15)
        if response.status_code == 200:
            models_data = response.json().get("data", [])
            available_models = [model.get("id") for model in models_data]
            print(f"✓ Connection successful!")
            print(f"Available models: {available_models}")
            return True
        else:
            print(f"✗ API connection failed: Status {response.status_code}")
            
            # Пробуем запрос через curl
            try:
                import subprocess
                print("\nTrying direct curl request:")
                curl_cmd = [
                    "curl", "-s", "-H", "Content-Type: application/json",
                    "-d", "{\"model\":\"gemma-3-4b-it-qat\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}",
                    f"{LM_STUDIO_URL}/v1/chat/completions"
                ]
                print(f"Running: {' '.join(curl_cmd)}")
                
                curl_result = subprocess.run(curl_cmd, capture_output=True, text=True)
                print(f"Curl result (status {curl_result.returncode}):")
                print(curl_result.stdout[:500])  # Показываем только первые 500 символов
                if curl_result.stderr:
                    print(f"Curl error: {curl_result.stderr}")
                
                if curl_result.returncode == 0 and curl_result.stdout and "content" in curl_result.stdout:
                    print("✓ Curl connection successful!")
                    return True
            except Exception as curl_error:
                print(f"✗ Curl failed: {str(curl_error)}")
            
            return False
    except Exception as e:
        print(f"✗ Unexpected error: {str(e)}")
        return False

def run_server_in_thread():
    """Run Flask server in a background thread"""
    def server_thread():
        app.run(host='0.0.0.0', port=SERVER_PORT, threaded=True)
    
    thread = threading.Thread(target=server_thread)
    thread.daemon = True
    thread.start()
    print(f"Server starting in background thread at http://localhost:{SERVER_PORT}")
    print("Waiting 5 seconds for server to initialize...")
    time.sleep(5)  # Give server time to start
    return thread

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