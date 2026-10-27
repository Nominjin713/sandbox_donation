import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.restoreSession();
  runApp(VolunteerApp(authService: authService));
}

class VolunteerApp extends StatelessWidget {
  const VolunteerApp({super.key, this.authService});
  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Volunteer Hub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7353BA),
          secondary: const Color(0xFFFFD166),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F6FF),
      ),
      home: HomePage(authService: authService),
    );
  }
}
