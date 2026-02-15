import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/app_state_provider.dart';

void main() {
  runApp(AutotabApp());
}

class AutotabApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: MaterialApp(
        title: 'Autotab - Rock Your Tabs',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.red[600],
          scaffoldBackgroundColor: Colors.black,
          colorScheme: ColorScheme.dark(
            primary: Colors.red[600]!,
            secondary: Colors.red[700]!,
            surface: Colors.grey[900]!,
            background: Colors.black,
            error: Colors.red[400]!,
          ),
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: Colors.grey[300]),
            bodyMedium: TextStyle(color: Colors.grey[400]),
          ),
          cardTheme: CardThemeData(
            color: Colors.grey[900],
            elevation: 4,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.red[600],
            elevation: 0,
            centerTitle: true,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: HomeScreen(),
      ),
    );
  }
}