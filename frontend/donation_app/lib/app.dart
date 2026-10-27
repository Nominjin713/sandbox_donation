import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'services/auth_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authService});
  final AuthService? authService;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Хандив',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7353BA),
        secondary: const Color(0xFFFFD166),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F6FF),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFFF8F6FF),
      ),
    ),
    home: HomePage(authService: authService),
  );
}
