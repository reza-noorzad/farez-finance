import 'package:flutter/material.dart';

class AppTheme {
  // Diese Klasse enthält das zentrale Design der App.
  // Wenn wir später Farben oder Schrift ändern wollen,
  // machen wir das nur hier und nicht in jeder einzelnen Seite.

  static ThemeData lightTheme = ThemeData(
    // Material 3 gibt der App ein modernes Flutter-Design.
    useMaterial3: true,

    // Diese Hauptfarbe wird für Buttons, AppBar und wichtige Elemente genutzt.
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: Brightness.light,
    ),

    // Diese Farbe wird als Hintergrund der App genutzt.
    scaffoldBackgroundColor: const Color(0xFFF7F9FC),

    // Hier definieren wir das Aussehen der oberen App-Leiste.
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A1A),
      elevation: 0,
    ),
  );
}