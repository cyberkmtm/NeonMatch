import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B0F1A),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00F5FF),
      secondary: Color(0xFF8A2BE2),
      surface: Color(0xFF161B2B),
    ),
    useMaterial3: true,
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    colorScheme: const ColorScheme.light(
      primary: Color(
        0xFF0066FF,
      ), // Slightly darker blue for light mode visibility
      secondary: Color(0xFF8A2BE2),
      surface: Colors.white,
    ),
    useMaterial3: true,
  );
}
