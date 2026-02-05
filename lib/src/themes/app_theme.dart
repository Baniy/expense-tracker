import 'package:flutter/material.dart';

class AppTheme {
  static final Color primary = const Color(0xFF3B82F6);
  static final Color accent = const Color(0xFF10B981);

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
    primaryColor: primary,
    appBarTheme: const AppBarTheme(centerTitle: true),
    iconTheme: const IconThemeData(color: Colors.black87),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: primary),
    useMaterial3: true,
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
    primaryColor: primary,
    appBarTheme: const AppBarTheme(centerTitle: true),
    iconTheme: const IconThemeData(color: Colors.white70),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: accent),
    useMaterial3: true,
  );
}
