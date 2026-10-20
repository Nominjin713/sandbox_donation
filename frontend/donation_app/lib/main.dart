import 'package:flutter/material.dart';

import 'screens/home_page.dart';

void main() {
  runApp(const VolunteerApp());
}

class VolunteerApp extends StatelessWidget {
  const VolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Volunteer Hub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087765)),
      ),
      home: const HomePage(),
    );
  }
}
