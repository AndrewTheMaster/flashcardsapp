import 'package:flutter/material.dart';
import '../models/settings_model.dart';

class AppLocalizations {
  final AppLanguage language;

  AppLocalizations(this.language);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(AppLanguage.english);
  }

  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Flashcards',
      'welcome_message': 'Welcome to Flashcards App',
      'create_new_pack': 'Create New Pack',
      'enter_pack_name': 'Enter pack name',
      'enter_characters': 'Enter characters (one per line)',
      'cancel': 'Cancel',
      'create': 'Create',
      'cards_to_review': 'Card to review',
      'no_cards_in_pack': 'No cards in this pack',
      'again_button': 'Again',
      'good_button': 'Good',
      'new_pack': 'New Pack',
      'next_card': 'Next Card',
      'settings': 'Settings',
      'theme': 'Theme',
      'language': 'Language',
      'light_mode': 'Light Mode',
      'dark_mode': 'Dark Mode',
      'system_mode': 'System Mode',
      'english': 'English',
      'russian': 'Russian',
      'fill_blanks': 'Fill in the Blanks',
      'no_cards_available': 'No cards available',
      'correct_answer': 'Correct answer',
      'check': 'Check',
      'next': 'Next',
      'flashcards': 'Flashcards',
      'edit_cards': 'Edit Cards',
      'memory_game': 'Memory Game',
      'victory': 'Victory!',
      'found_all_pairs': 'You found all pairs!',
      'play_again': 'Play Again',
      'find_matching_pairs': 'Find matching pairs',
      'edit_flashcard': 'Edit Flashcard',
      'hanzi': 'Character',
      'pinyin': 'Pinyin',
      'translation': 'Translation',
      'save': 'Save',
      'suggested_translation': 'Suggested translation:',
      'translation_error': 'Translation error',
      'required_fields_error': 'Please fill in all required fields',
      'exercises': 'Exercises',
    },
    'ru': {
      'app_title': 'Карточки',
      'welcome_message': 'Добро пожаловать в приложение Карточки',
      'create_new_pack': 'Создать новый набор',
      'enter_pack_name': 'Введите название набора',
      'enter_characters': 'Введите символы (по одному в строке)',
      'cancel': 'Отмена',
      'create': 'Создать',
      'cards_to_review': 'Карточка для повторения',
      'no_cards_in_pack': 'В этом наборе нет карточек',
      'again_button': 'Снова',
      'good_button': 'Хорошо',
      'new_pack': 'Новый набор',
      'next_card': 'Следующая карточка',
      'settings': 'Настройки',
      'theme': 'Тема',
      'language': 'Язык',
      'light_mode': 'Светлая тема',
      'dark_mode': 'Тёмная тема',
      'system_mode': 'Системная тема',
      'english': 'Английский',
      'russian': 'Русский',
      'fill_blanks': 'Заполните пропуски',
      'no_cards_available': 'Нет доступных карточек',
      'correct_answer': 'Правильный ответ',
      'check': 'Проверить',
      'next': 'Далее',
      'flashcards': 'Карточки',
      'edit_cards': 'Редактировать карточки',
      'memory_game': 'Игра на память',
      'victory': 'Победа!',
      'found_all_pairs': 'Вы нашли все пары!',
      'play_again': 'Играть снова',
      'find_matching_pairs': 'Найдите соответствующие пары',
      'edit_flashcard': 'Редактировать карточку',
      'hanzi': 'Символ',
      'pinyin': 'Пиньинь',
      'translation': 'Перевод',
      'save': 'Сохранить',
      'suggested_translation': 'Предложенный перевод:',
      'translation_error': 'Ошибка перевода',
      'required_fields_error': 'Пожалуйста, заполните все обязательные поля',
      'exercises': 'Упражнения',
    },
  };

  String translate(String key) {
    final languageCode = language == AppLanguage.russian ? 'ru' : 'en';
    return _localizedValues[languageCode]?[key] ?? key;
  }

  static String staticTranslate(AppLanguage language, String key) {
    final languageCode = language == AppLanguage.russian ? 'ru' : 'en';
    return _localizedValues[languageCode]?[key] ?? key;
  }
}

// Extension method for String to easily use translations
extension StringExtension on String {
  String tr(BuildContext context) {
    return AppLocalizations.of(context).translate(this);
  }
} 