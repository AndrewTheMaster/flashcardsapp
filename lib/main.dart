import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/cards_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'localization/app_localization_delegate.dart';
import 'localization/app_localizations.dart';
import 'models/settings_model.dart';
import 'services/exercise_service_facade.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Создаем экземпляр SettingsProvider
  final settingsProvider = SettingsProvider();
  
  // Загружаем настройки до запуска приложения
  await settingsProvider.loadSettings();
  
  // Создаем экземпляр CardsProvider
  final cardsProvider = CardsProvider();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsProvider),
        // Добавляем ExerciseServiceFacade как Provider для доступа из любого места
        Provider(create: (context) => ExerciseServiceFacade(
          Provider.of<SettingsProvider>(context, listen: false)
        )),
        ChangeNotifierProvider(create: (_) => cardsProvider),
        // Другие провайдеры, если они есть
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    // Получаем текущий язык и тему
    final currentLanguage = settingsProvider.language;
    final currentThemeMode = settingsProvider.themeMode;
    
    return MaterialApp(
      title: AppLocalizations.staticTranslate(currentLanguage, 'app_title'),
      
      // Настройка локализации
      localizationsDelegates: [
        AppLocalizationsDelegate(currentLanguage),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ru', ''), // Russian
      ],
      locale: currentLanguage == AppLanguage.russian 
          ? const Locale('ru', '') 
          : const Locale('en', ''),
      
      // Настройка темы
      themeMode: currentThemeMode,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 18.0),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 18.0, color: Colors.white),
        ),
      ),
      
      home: HomeScreen(),
    );
  }
}
