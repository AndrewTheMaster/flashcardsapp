from transformers import MarianMTModel, MarianTokenizer
import logging
import torch
import os
import time

class Translator:
    """
    Bidirectional translator using Helsinki-NLP models to translate between:
    - Chinese to English
    - English to Russian
    - Russian to English
    - English to Chinese
    - Russian to Chinese (via English)
    - Chinese to Russian (via English)
    """
    
    def __init__(self):
        logging.info("Initializing Helsinki-NLP translation models")
        self.models = {}
        self.tokenizers = {}
        
        # Define model configurations
        self.model_configs = {
            "zh-en": "Helsinki-NLP/opus-mt-zh-en",
            "en-zh": "Helsinki-NLP/opus-mt-en-zh",
            "en-ru": "Helsinki-NLP/opus-mt-en-ru",
            "ru-en": "Helsinki-NLP/opus-mt-ru-en"
        }
        
        # Настраиваем кэш-директорию для моделей
        models_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models")
        os.makedirs(models_dir, exist_ok=True)
        os.environ["TRANSFORMERS_CACHE"] = models_dir
        
        logging.info(f"Models cache directory: {models_dir}")
        
        # Предварительно загружаем самые важные модели при инициализации
        try:
            # Приоритетные языковые пары: китайский <-> английский
            self._load_model("zh-en")
            self._load_model("en-zh")
            logging.info("Primary translation models (zh-en, en-zh) pre-loaded")
        except Exception as e:
            logging.warning(f"Failed to pre-load primary models: {e}")
            logging.info("Models will be loaded on-demand")
        
    def _load_model(self, lang_pair):
        """Load a specific translation model on demand"""
        if lang_pair not in self.model_configs:
            raise ValueError(f"Unsupported language pair: {lang_pair}")
        
        if lang_pair not in self.models:
            logging.info(f"Loading translation model for {lang_pair}")
            model_name = self.model_configs[lang_pair]
            
            max_retries = 2
            for attempt in range(max_retries):
                try:
                    start_time = time.time()
                    self.tokenizers[lang_pair] = MarianTokenizer.from_pretrained(model_name, local_files_only=False)
                    logging.info(f"Tokenizer for {lang_pair} loaded in {time.time() - start_time:.2f}s")
                    
                    start_time = time.time()
                    self.models[lang_pair] = MarianMTModel.from_pretrained(model_name, local_files_only=False)
                    logging.info(f"Model for {lang_pair} loaded in {time.time() - start_time:.2f}s")
                    
                    # Move to GPU if available
                    if torch.cuda.is_available():
                        self.models[lang_pair].to("cuda")
                        logging.info(f"Model {lang_pair} moved to GPU")
                    
                    logging.info(f"Successfully loaded {lang_pair} model")
                    return
                except Exception as e:
                    logging.error(f"Error loading {lang_pair} model (attempt {attempt+1}/{max_retries}): {str(e)}")
                    if attempt < max_retries - 1:
                        wait_time = 2 ** attempt
                        logging.info(f"Retrying in {wait_time} seconds...")
                        time.sleep(wait_time)
            
            # Если все попытки не удались
            raise ValueError(f"Failed to load {lang_pair} model after {max_retries} attempts")
    
    def translate(self, text, source_lang, target_lang):
        """Translate text from source language to target language"""
        logging.info(f"Translating from {source_lang} to {target_lang}: {text[:50]}...")
        
        # Direct translation if model exists
        lang_pair = f"{source_lang}-{target_lang}"
        if lang_pair in self.model_configs:
            return self._direct_translate(text, lang_pair)
        
        # Two-step translation via English
        if f"{source_lang}-en" in self.model_configs and f"en-{target_lang}" in self.model_configs:
            logging.info(f"Using two-step translation via English")
            try:
                english = self._direct_translate(text, f"{source_lang}-en")
                return self._direct_translate(english, f"en-{target_lang}")
            except Exception as e:
                logging.error(f"Two-step translation failed: {e}")
                return f"[Translation error: {str(e)}]"
        
        # Unsupported language pair
        error_msg = f"Unsupported translation direction: {source_lang} to {target_lang}"
        logging.error(error_msg)
        return f"[{error_msg}]"
    
    def _direct_translate(self, text, lang_pair):
        """Internal method to translate using a specific model"""
        try:
            # Load model if not already loaded
            if lang_pair not in self.models:
                self._load_model(lang_pair)
            
            # Prepare for translation
            tokenizer = self.tokenizers[lang_pair]
            model = self.models[lang_pair]
            
            # Check if text is empty
            if not text.strip():
                return ""
            
            # Tokenize
            device = "cuda" if torch.cuda.is_available() else "cpu"
            encoded = tokenizer(text, return_tensors="pt", padding=True).to(device)
            
            # Translate
            with torch.no_grad():
                output = model.generate(**encoded)
            
            # Decode and return
            translated = tokenizer.batch_decode(output, skip_special_tokens=True)[0]
            logging.info(f"Translation successful. Result: {translated[:50]}...")
            return translated
            
        except Exception as e:
            logging.error(f"Translation error ({lang_pair}): {str(e)}")
            return f"[Translation error: {str(e)}]"
    
    def process_text(self, text, source_lang=None, target_lang=None, need_pinyin=False):
        """
        Process text for translation and fill missing fields.
        Returns a dictionary with translations in different languages and pinyin if needed.
        """
        result = {"original": text}
        
        # Detect language if not provided
        if not source_lang:
            source_lang = self._detect_language(text)
            result["detected_language"] = source_lang
        
        # Short circuit if no text or no target language
        if not text.strip() or not target_lang:
            return result
            
        # Handle translations based on what we have
        if source_lang == "zh" and target_lang in ["en", "ru"]:
            # Chinese to target language
            if target_lang == "en":
                result["english"] = self.translate(text, "zh", "en")
                if "ru" in self.model_configs:
                    result["russian"] = self.translate(result["english"], "en", "ru")
            else:  # target_lang == "ru"
                # First to English, then to Russian
                result["english"] = self.translate(text, "zh", "en")
                result["russian"] = self.translate(result["english"], "en", "ru")
                
        elif source_lang == "en" and target_lang in ["zh", "ru"]:
            # English to target language
            if target_lang == "zh":
                result["chinese"] = self.translate(text, "en", "zh")
            else:  # target_lang == "ru"
                result["russian"] = self.translate(text, "en", "ru")
                
        elif source_lang == "ru" and target_lang in ["zh", "en"]:
            # Russian to target language
            if target_lang == "en":
                result["english"] = self.translate(text, "ru", "en")
            else:  # target_lang == "zh"
                # First to English, then to Chinese
                result["english"] = self.translate(text, "ru", "en")
                result["chinese"] = self.translate(result["english"], "en", "zh")
                
        # Generate pinyin if needed and we have Chinese text
        if need_pinyin and (source_lang == "zh" or "chinese" in result):
            chinese_text = text if source_lang == "zh" else result.get("chinese", "")
            if chinese_text.strip():
                try:
                    import pypinyin
                    pinyin_list = pypinyin.pinyin(chinese_text, style=pypinyin.Style.TONE)
                    result["pinyin"] = " ".join([item[0] for item in pinyin_list])
                except Exception as e:
                    logging.error(f"Error generating pinyin: {str(e)}")
                    result["pinyin"] = "[Pinyin generation error]"
            
        return result
    
    def _detect_language(self, text):
        """Simple language detection based on character sets"""
        if not text or not isinstance(text, str):
            return "unknown"
            
        # Check for Chinese characters
        chinese_chars = sum(1 for char in text if '\u4e00' <= char <= '\u9fff')
        if chinese_chars > len(text) * 0.2:  # If more than 20% are Chinese
            return "zh"
            
        # Check for Russian Cyrillic
        russian_chars = sum(1 for char in text if '\u0410' <= char <= '\u044F')
        if russian_chars > len(text) * 0.2:  # If more than 20% are Russian
            return "ru"
            
        # Default to English
        return "en" 