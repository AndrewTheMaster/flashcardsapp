import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/cards_provider.dart';
import 'screens/fill_blanks_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CardsProvider()),
        // Другие провайдеры, если они у вас есть
      ],
      child: MaterialApp(
        title: 'Chinese Learning App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          textTheme: TextTheme(
            displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            bodyLarge: TextStyle(fontSize: 18.0),
          ),
        ),
        home: HomeScreen(),
      ),
    );
  }
}
