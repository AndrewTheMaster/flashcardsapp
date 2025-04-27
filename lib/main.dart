import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'providers/cards_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'localization/app_localization_delegate.dart';
import 'localization/app_localizations.dart';
import 'models/settings_model.dart';
import 'services/model_service_provider.dart';
import 'dart:developer' as developer;
import 'utils/tflite_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create SettingsProvider instance and load settings
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();
  
  // Initialize TFLite
  try {
    await Tflite.initTFLite();
    developer.log('Main: TFLite initialized successfully', name: 'main');
  } catch (e) {
    developer.log('Main: Error initializing TFLite: $e', name: 'main');
  }
  
  // Initialize the ML model in background
  _initializeModelService();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => CardsProvider()),
        // Other providers, if any
      ],
      child: const MyApp(),
    ),
  );
}

// Initialize the model service in the background
void _initializeModelService() {
  // Start initialization asynchronously but don't wait for it
  ModelServiceProvider.initialize().then((success) {
    if (success) {
      developer.log('Main: ML model initialized successfully', name: 'main');
      developer.log('Main: Using ${ModelServiceProvider.getCurrentImplementation()} implementation', name: 'main');
    } else {
      developer.log('Main: Failed to initialize ML model', name: 'main');
    }
  }).catchError((error) {
    developer.log('Main: Error initializing ML model: $error', name: 'main');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    // Get current language and theme
    final currentLanguage = settingsProvider.language;
    final currentThemeMode = settingsProvider.themeMode;
    
    return MaterialApp(
      title: AppLocalizations.staticTranslate(currentLanguage, 'app_title'),
      
      // Localization setup
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
      
      // Theme setup
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
