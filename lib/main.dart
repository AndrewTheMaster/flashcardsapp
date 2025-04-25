import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/cards_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'localization/app_localization_delegate.dart';
import 'localization/app_localizations.dart';
import 'models/settings_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Создаем экземпляр SettingsProvider и загружаем настройки
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => CardsProvider()),
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
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 18.0),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 18.0, color: Colors.white),
        ),
      ),
      
      home: HomeScreen(),
    );
  }
}
