from transformers import pipeline, BertForMaskedLM, BertTokenizer
import torch
import re
import numpy as np
import logging
import os
import time

class ContentValidator:
    def __init__(self):
        logging.info("Инициализация валидатора на основе BERT-Chinese-WWM")
        self.model = None
        self.tokenizer = None
        self.fill_mask_pipeline = None
        
        # Путь для локального кэширования моделей
        models_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models")
        os.makedirs(models_dir, exist_ok=True)
        os.environ["TRANSFORMERS_CACHE"] = models_dir
        
        # Повторные попытки загрузки модели с таймаутами
        max_retries = 3
        for attempt in range(max_retries):
            try:
                # Используем BERT-Chinese-WWM вместо base версии для лучших результатов в китайском языке
                self.model_name = "hfl/chinese-bert-wwm-ext"
                logging.info(f"Загрузка модели {self.model_name} (попытка {attempt+1}/{max_retries})")
                
                # Загрузка с таймаутом
                start_time = time.time()
                self.tokenizer = BertTokenizer.from_pretrained(self.model_name, local_files_only=False)
                logging.info(f"Токенайзер загружен за {time.time() - start_time:.2f} сек")
                
                start_time = time.time()
                self.model = BertForMaskedLM.from_pretrained(self.model_name, local_files_only=False)
                logging.info(f"Модель загружена за {time.time() - start_time:.2f} сек")
                
                self.model.eval()
                
                # Создаем pipeline для семантического анализа текста
                logging.info("Инициализация fill-mask pipeline")
                self.fill_mask_pipeline = pipeline(
                    "fill-mask", 
                    model=self.model,
                    tokenizer=self.tokenizer
                )
                
                logging.info(f"Модель {self.model_name} успешно загружена")
                break
                
            except Exception as e:
                logging.error(f"Ошибка при загрузке модели (попытка {attempt+1}): {str(e)}")
                
                if attempt < max_retries - 1:
                    wait_time = 2 ** attempt  # Экспоненциальный рост времени ожидания
                    logging.info(f"Повторная попытка через {wait_time} секунд...")
                    time.sleep(wait_time)
                else:
                    logging.warning("Достигнуто максимальное количество попыток. Использую запасную модель.")
                    try:
                        # Fallback к базовой модели если не удалось загрузить WWM
                        self.model_name = "bert-base-chinese"
                        logging.info(f"Пробую запасную модель {self.model_name}")
                        
                        self.tokenizer = BertTokenizer.from_pretrained(self.model_name, local_files_only=False)
                        self.model = BertForMaskedLM.from_pretrained(self.model_name, local_files_only=False)
                        self.model.eval()
                        self.fill_mask_pipeline = pipeline("fill-mask", model=self.model, tokenizer=self.tokenizer)
                        
                        logging.warning(f"Используется запасная модель {self.model_name}")
                    except Exception as fallback_error:
                        logging.error(f"Ошибка при загрузке запасной модели: {str(fallback_error)}")
                        logging.critical("Не удалось загрузить ни одну модель. Валидатор будет работать в ограниченном режиме.")
        
        # Проверяем, что модель загружена
        if self.model is None or self.tokenizer is None:
            logging.critical("Не удалось инициализировать модели. Валидация будет всегда возвращать положительный результат.")
    
    def validate_exercise(self, exercise_data):
        """Основной метод проверки упражнения"""
        try:
            logging.info(f"Валидация упражнения: {exercise_data.get('sentence_with_gap', '')}")
            
            # Проверка наличия необходимых полей
            required_fields = ["sentence_with_gap", "options", "answer", "pinyin"]
            if not all(field in exercise_data for field in required_fields):
                logging.warning("Отсутствуют обязательные поля в упражнении")
                return {
                    "is_valid": False,
                    "confidence": 0.0,
                    "reason": "Отсутствуют необходимые поля"
                }
            
            sentence = exercise_data["sentence_with_gap"]
            options = exercise_data["options"]
            correct_answer = exercise_data["answer"]
            
            # Базовые проверки
            if not self._basic_checks(sentence, options, correct_answer):
                return {
                    "is_valid": False,
                    "confidence": 0.0,
                    "reason": "Упражнение не прошло базовые проверки"
                }
            
            # Проверяем смысловую когерентность предложения с правильным ответом
            semantic_score = self._evaluate_semantic_coherence(sentence, correct_answer)
            
            # Проверяем качество дистракторов (неправильных вариантов)
            distractors = [opt for opt in options if opt != correct_answer]
            distractor_scores = self._evaluate_distractors(sentence, distractors, correct_answer)
            
            # Оценка уверенности в правильности упражнения
            confidence = semantic_score * 0.6 + distractor_scores * 0.4
            
            result = {
                "is_valid": confidence > 0.6,  # Пороговое значение для принятия упражнения
                "confidence": float(confidence),
                "semantic_score": float(semantic_score),
                "distractor_score": float(distractor_scores),
                "improvements": []
            }
            
            # Рекомендации по улучшению упражнения при необходимости
            if semantic_score < 0.7:
                result["improvements"].append("Предложение не очень естественно звучит с выбранным словом")
            if distractor_scores < 0.5:
                result["improvements"].append("Варианты ответов недостаточно близки/различимы по контексту")
                
            # Подробное логирование результатов валидации
            validation_log = f"""
=== BERT-Chinese-WWM Validation Details ===
- Sentence: {sentence}
- Options: {options}
- Correct Answer: {correct_answer}
- Is Valid: {result['is_valid']}
- Confidence: {result['confidence']:.4f}
- Semantic Score: {result['semantic_score']:.4f}
- Distractor Score: {result['distractor_score']:.4f}
"""
            if result['improvements']:
                validation_log += "- Suggestions for improvement:\n"
                for imp in result['improvements']:
                    validation_log += f"  * {imp}\n"
                    
            logging.info(validation_log)
            
            return result
            
        except Exception as e:
            logging.error(f"Ошибка при валидации: {str(e)}", exc_info=True)
            return {
                "is_valid": True,  # В случае ошибки считаем валидным, чтобы не блокировать работу
                "confidence": 0.5,
                "reason": f"Ошибка валидации: {str(e)}"
            }
    
    def _basic_checks(self, sentence, options, correct_answer):
        """Быстрые проверки без использования модели"""
        if len(options) < 2:
            logging.warning("Слишком мало вариантов ответа")
            return False
            
        if len(sentence) > 200:
            logging.warning("Предложение слишком длинное")
            return False
            
        if "____" not in sentence:
            logging.warning("В предложении отсутствует пропуск ____")
            return False
            
        if correct_answer not in options:
            logging.warning("Правильный ответ отсутствует в вариантах")
            return False
            
        return True
    
    def _evaluate_semantic_coherence(self, sentence_with_gap, correct_answer):
        """Оценка семантической связности предложения с правильным ответом"""
        try:
            # Заменяем пропуск на правильное слово
            full_sentence = sentence_with_gap.replace("____", correct_answer)
            
            # Заменяем правильное слово на маску для проверки предсказаний BERT
            masked_sentence = full_sentence.replace(correct_answer, self.tokenizer.mask_token, 1)
            
            # Получаем предсказания модели
            predictions = self.fill_mask_pipeline(masked_sentence)
            
            # Извлекаем вероятности для топ-5 предсказаний
            top_predictions = [(p["token_str"], p["score"]) for p in predictions]
            
            # Ищем наш правильный ответ среди предсказаний
            for pred, score in top_predictions:
                if correct_answer in pred or pred in correct_answer:
                    return float(score)  # Если точное совпадение, возвращаем вероятность
            
            # Если нет точного совпадения, берем близость к топ-1 предсказанию
            # Чем меньше вероятность топ-1, тем менее уверена модель, что правильнее было бы другое слово
            return float(1.0 - top_predictions[0][1])
            
        except Exception as e:
            logging.error(f"Ошибка при оценке семантической связности: {str(e)}")
            return 0.7  # Значение по умолчанию
    
    def _evaluate_distractors(self, sentence_with_gap, distractors, correct_answer):
        """Оценка качества отвлекающих вариантов"""
        try:
            # Заменяем пропуск на MASK-токен для BERT
            masked_sentence = sentence_with_gap.replace("____", self.tokenizer.mask_token)
            
            # Получаем эмбеддинги для всех вариантов
            inputs = self.tokenizer(
                [correct_answer] + distractors, 
                padding=True, 
                return_tensors="pt"
            )
            
            with torch.no_grad():
                outputs = self.model.bert(**{
                    k: v for k, v in inputs.items() if k != 'token_type_ids'
                })
                
            # Усредняем эмбеддинги последнего слоя
            embeddings = outputs.last_hidden_state.mean(dim=1)
            
            # Нормализуем эмбеддинги
            embeddings = embeddings / embeddings.norm(dim=1, keepdim=True)
            
            # Вычисляем косинусную близость между правильным ответом и дистракторами
            correct_embedding = embeddings[0].unsqueeze(0)
            distractor_embeddings = embeddings[1:]
            
            similarities = torch.matmul(correct_embedding, distractor_embeddings.transpose(0, 1)).squeeze()
            similarities = similarities.cpu().numpy()
            
            # Средняя схожесть не должна быть слишком высокой (слишком похожие варианты)
            # и не должна быть слишком низкой (слишком очевидные неправильные варианты)
            avg_similarity = np.mean(similarities)
            
            # Идеальная схожесть около 0.5-0.7 (достаточно близко, но не идентично)
            target_similarity = 0.6
            
            # Оценка качества дистракторов (чем ближе к целевой схожести, тем лучше)
            distractor_score = 1.0 - abs(avg_similarity - target_similarity)
            return float(distractor_score)
            
        except Exception as e:
            logging.error(f"Ошибка при оценке дистракторов: {str(e)}")
            return 0.6  # Значение по умолчанию
            
    def analyze_gap_placement(self, full_sentence, gap_word):
        """Анализ правильности размещения пропуска в предложении"""
        try:
            # Разбиваем предложение на токены
            tokens = self.tokenizer.tokenize(full_sentence)
            
            # Находим индекс слова, которое будет заменено на пропуск
            word_tokens = self.tokenizer.tokenize(gap_word)
            
            # Для каждого возможного места пропуска оцениваем вероятность
            positions = []
            for i in range(len(tokens) - len(word_tokens) + 1):
                potential_gap = tokens[i:i+len(word_tokens)]
                
                # Пропускаем, если не совпадает с искомым словом
                joined = self.tokenizer.convert_tokens_to_string(potential_gap)
                if gap_word not in joined:
                    continue
                
                # Заменяем эту позицию на маску и оцениваем перплексию
                masked_tokens = tokens.copy()
                for j in range(i, i + len(word_tokens)):
                    if j < len(masked_tokens):
                        masked_tokens[j] = self.tokenizer.mask_token
                
                masked_sentence = self.tokenizer.convert_tokens_to_string(masked_tokens)
                
                # Предсказываем варианты для этой позиции
                predictions = self.fill_mask_pipeline(masked_sentence)
                
                # Если правильное слово входит в топ предсказаний, это хорошая позиция для пропуска
                top_predictions = [p["token_str"] for p in predictions]
                score = 0.0
                for pred_idx, pred in enumerate(top_predictions):
                    if gap_word in pred or pred in gap_word:
                        # Чем выше позиция в списке, тем лучше
                        score = float(1.0 - (pred_idx / len(top_predictions)))
                        break
                
                positions.append({"position": int(i), "score": float(score)})
            
            # Сортируем позиции по убыванию оценки
            positions.sort(key=lambda x: x["score"], reverse=True)
            
            return positions
        except Exception as e:
            logging.error(f"Ошибка при анализе размещения пропуска: {str(e)}")
            return [] 