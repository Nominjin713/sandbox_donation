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
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F6B)),
      scaffoldBackgroundColor: const Color(0xFFF3F7F6),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFFF8FAF9),
      ),
    ),
    home: HomePage(authService: authService),
  );
}
