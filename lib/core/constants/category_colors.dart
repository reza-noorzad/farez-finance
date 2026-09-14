import 'package:flutter/material.dart';

class CategoryColors {
  // Diese Klasse enthält Farben, die der Benutzer für Kategorien auswählen kann.
  // In der Datenbank speichern wir später den int-Wert der Farbe.

  static const List<Color> colors = [
    Color(0xFF1E88E5), // Blau
    Color(0xFF43A047), // Grün
    Color(0xFFFB8C00), // Orange
    Color(0xFFE53935), // Rot
    Color(0xFF8E24AA), // Lila
    Color(0xFF00897B), // Türkis
    Color(0xFF6D4C41), // Braun
    Color(0xFF3949AB), // Indigo
    Color(0xFFFDD835), // Gelb
    Color(0xFF546E7A), // Blau-Grau
  ];

  static Color getColor(int colorValue) {
    // Diese Funktion macht aus einem gespeicherten int-Wert wieder eine Color.
    return Color(colorValue);
  }
}