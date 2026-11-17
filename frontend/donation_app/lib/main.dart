import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

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
      theme: buildBrandTheme(),
      builder: (context, child) =>
          BrandBackground(child: child ?? const SizedBox.shrink()),
      home: HomePage(authService: authService),
    );
  }
}
