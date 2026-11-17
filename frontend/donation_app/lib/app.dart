import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authService});
  final AuthService? authService;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Хандив',
    debugShowCheckedModeBanner: false,
    theme: buildBrandTheme(),
    builder: (context, child) =>
        BrandBackground(child: child ?? const SizedBox.shrink()),
    home: HomePage(authService: authService),
  );
}
