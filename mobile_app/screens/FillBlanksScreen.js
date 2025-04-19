import React, { useState, useEffect } from 'react';
import { 
  View, 
  Text, 
  TextInput, 
  StyleSheet, 
  TouchableOpacity, 
  ScrollView,
  ActivityIndicator,
  Alert
} from 'react-native';
import { generateCards } from '../api/bertApi';

const FillBlanksScreen = () => {
  const [loading, setLoading] = useState(true);
  const [cards, setCards] = useState([]);
  const [currentCardIndex, setCurrentCardIndex] = useState(0);
  const [userAnswers, setUserAnswers] = useState({});
  const [showResults, setShowResults] = useState(false);
  const [difficulty, setDifficulty] = useState('medium');
  const [category, setCategory] = useState('all');

  useEffect(() => {
    loadCards();
  }, []);

  const loadCards = async () => {
    try {
      setLoading(true);
      const response = await generateCards(category, difficulty, 5);
      setCards(response.cards);
      setUserAnswers({});
      setShowResults(false);
      setCurrentCardIndex(0);
    } catch (error) {
      Alert.alert('Ошибка', 'Не удалось загрузить карточки');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleAnswerChange = (index, text) => {
    setUserAnswers({
      ...userAnswers,
      [index]: text
    });
  };

  const checkAnswers = () => {
    setShowResults(true);
  };

  const nextCard = () => {
    if (currentCardIndex < cards.length - 1) {
      setCurrentCardIndex(currentCardIndex + 1);
    }
  };

  const prevCard = () => {
    if (currentCardIndex > 0) {
      setCurrentCardIndex(currentCardIndex - 1);
    }
  };

  const renderCard = () => {
    if (loading || cards.length === 0) {
      return (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#0066cc" />
          <Text style={styles.loadingText}>Загрузка карточек...</Text>
        </View>
      );
    }

    const card = cards[currentCardIndex];
    const maskedText = card.masked_text;
    
    // Разделение текста по маскам для создания полей ввода
    const parts = maskedText.split('[MASK]');
    
    return (
      <ScrollView style={styles.cardContainer}>
        <Text style={styles.cardNumber}>
          Карточка {currentCardIndex + 1} из {cards.length}
        </Text>
        
        <View style={styles.textContainer}>
          {parts.map((part, index) => (
            <React.Fragment key={index}>
              <Text style={styles.textPart}>{part}</Text>
              {index < parts.length - 1 && (
                <TextInput
                  style={styles.blankInput}
                  placeholder="填空"
                  value={userAnswers[`${currentCardIndex}-${index}`] || ''}
                  onChangeText={(text) => handleAnswerChange(`${currentCardIndex}-${index}`, text)}
                  editable={!showResults}
                />
              )}
            </React.Fragment>
          ))}
        </View>
        
        {showResults && (
          <View style={styles.resultsContainer}>
            <Text style={styles.resultsTitle}>Правильные ответы:</Text>
            <Text style={styles.originalText}>{card.original_text}</Text>
          </View>
        )}
      </ScrollView>
    );
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>填空练习 (Заполните пропуски)</Text>
        
        <View style={styles.controls}>
          <TouchableOpacity 
            style={[styles.difficultyButton, difficulty === 'easy' && styles.activeButton]} 
            onPress={() => setDifficulty('easy')}
          >
            <Text style={styles.buttonText}>Легко</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            style={[styles.difficultyButton, difficulty === 'medium' && styles.activeButton]} 
            onPress={() => setDifficulty('medium')}
          >
            <Text style={styles.buttonText}>Средне</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            style={[styles.difficultyButton, difficulty === 'hard' && styles.activeButton]} 
            onPress={() => setDifficulty('hard')}
          >
            <Text style={styles.buttonText}>Сложно</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.categoryControls}>
          <TouchableOpacity 
            style={[styles.categoryButton, category === 'all' && styles.activeButton]} 
            onPress={() => setCategory('all')}
          >
            <Text style={styles.buttonText}>Все</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            style={[styles.categoryButton, category === 'greeting' && styles.activeButton]} 
            onPress={() => setCategory('greeting')}
          >
            <Text style={styles.buttonText}>Приветствия</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            style={[styles.categoryButton, category === 'food' && styles.activeButton]} 
            onPress={() => setCategory('food')}
          >
            <Text style={styles.buttonText}>Еда</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            style={[styles.categoryButton, category === 'travel' && styles.activeButton]} 
            onPress={() => setCategory('travel')}
          >
            <Text style={styles.buttonText}>Путешествия</Text>
          </TouchableOpacity>
        </View>
      </View>
      
      {renderCard()}
      
      <View style={styles.footer}>
        <TouchableOpacity 
          style={styles.navButton} 
          onPress={prevCard}
          disabled={currentCardIndex === 0}
        >
          <Text style={styles.navButtonText}>← Назад</Text>
        </TouchableOpacity>
        
        {!showResults ? (
          <TouchableOpacity style={styles.checkButton} onPress={checkAnswers}>
            <Text style={styles.checkButtonText}>Проверить</Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity style={styles.newCardsButton} onPress={loadCards}>
            <Text style={styles.checkButtonText}>Новые карточки</Text>
          </TouchableOpacity>
        )}
        
        <TouchableOpacity 
          style={styles.navButton} 
          onPress={nextCard}
          disabled={currentCardIndex === cards.length - 1}
        >
          <Text style={styles.navButtonText}>Вперед →</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    padding: 16,
    backgroundColor: '#ffffff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 12,
  },
  controls: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 8,
  },
  difficultyButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginHorizontal: 4,
    borderRadius: 20,
    backgroundColor: '#eeeeee',
  },
  categoryControls: {
    flexDirection: 'row',
    justifyContent: 'center',
    flexWrap: 'wrap',
  },
  categoryButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    marginHorizontal: 2,
    marginVertical: 4,
    borderRadius: 16,
    backgroundColor: '#eeeeee',
  },
  activeButton: {
    backgroundColor: '#0066cc',
  },
  buttonText: {
    fontWeight: '500',
    color: '#000000',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 16,
  },
  cardContainer: {
    flex: 1,
    padding: 16,
  },
  cardNumber: {
    textAlign: 'center',
    fontSize: 16,
    marginBottom: 16,
    color: '#666666',
  },
  textContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    padding: 16,
    borderRadius: 8,
    elevation: 2,
    shadowColor: '#000000',
    shadowOpacity: 0.1,
    shadowOffset: { width: 0, height: 2 },
    shadowRadius: 4,
  },
  textPart: {
    fontSize: 18,
    lineHeight: 24,
  },
  blankInput: {
    borderBottomWidth: 1,
    borderBottomColor: '#0066cc',
    minWidth: 60,
    height: 36,
    fontSize: 18,
    textAlign: 'center',
    margin: 4,
  },
  resultsContainer: {
    marginTop: 24,
    padding: 16,
    backgroundColor: '#e8f5e9',
    borderRadius: 8,
  },
  resultsTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  originalText: {
    fontSize: 18,
    lineHeight: 24,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 16,
    backgroundColor: '#ffffff',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  navButton: {
    padding: 8,
  },
  navButtonText: {
    fontSize: 16,
    color: '#0066cc',
  },
  checkButton: {
    backgroundColor: '#4caf50',
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 20,
  },
  newCardsButton: {
    backgroundColor: '#ff9800',
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 20,
  },
  checkButtonText: {
    color: '#ffffff',
    fontWeight: 'bold',
    fontSize: 16,
  },
});

export default FillBlanksScreen; 