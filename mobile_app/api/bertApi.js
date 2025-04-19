/**
 * API клиент для взаимодействия с BERT-сервером
 */
const BASE_URL = 'http://your-bert-server-address:8000/api';

/**
 * Генерирует текст с пропусками на основе предоставленного текста
 * @param {string} text - Исходный текст на китайском
 * @param {string} difficulty - Сложность: 'easy', 'medium', 'hard'
 * @param {number} numBlanks - Количество пропусков
 * @returns {Promise} - Объект с текстом с пропусками и ответами
 */
export const generateBlanks = async (text, difficulty = 'medium', numBlanks = 3) => {
  try {
    const response = await fetch(`${BASE_URL}/generate-blanks`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        text,
        difficulty,
        num_blanks: numBlanks,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.detail || 'Ошибка при генерации текста с пропусками');
    }

    return await response.json();
  } catch (error) {
    console.error('API ошибка (generateBlanks):', error);
    throw error;
  }
};

/**
 * Получает случайные карточки с текстами и пропусками
 * @param {string} category - Категория текстов ('greeting', 'food', 'travel', 'all')
 * @param {string} difficulty - Сложность: 'easy', 'medium', 'hard'
 * @param {number} numCards - Количество карточек
 * @returns {Promise} - Массив карточек с текстами и пропусками
 */
export const generateCards = async (category = 'all', difficulty = 'medium', numCards = 5) => {
  try {
    const response = await fetch(`${BASE_URL}/generate-cards`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        category,
        difficulty,
        num_cards: numCards,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.detail || 'Ошибка при генерации карточек');
    }

    return await response.json();
  } catch (error) {
    console.error('API ошибка (generateCards):', error);
    throw error;
  }
};

/**
 * Проверяет доступность сервера
 * @returns {Promise<boolean>} - true, если сервер доступен
 */
export const checkServerHealth = async () => {
  try {
    const response = await fetch(`${BASE_URL}/health`);
    return response.ok;
  } catch (error) {
    console.error('API ошибка (checkServerHealth):', error);
    return false;
  }
}; 