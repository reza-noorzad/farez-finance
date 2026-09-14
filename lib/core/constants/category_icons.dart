import 'package:flutter/material.dart';

class CategoryIcons {
  // Diese Klasse enthält alle Icons, die ein Benutzer für Kategorien auswählen kann.
  // Wir speichern später nur den Namen des Icons in der Datenbank.
  // Dadurch können wir das Icon jederzeit wieder aus dieser Liste laden.

  static const Map<String, IconData> icons = {
    'food': Icons.restaurant,
    'dog': Icons.pets,
    'car': Icons.directions_car,
    'home': Icons.home,
    'education': Icons.school,
    'fitness': Icons.fitness_center,
    'gift': Icons.card_giftcard,
    'travel': Icons.flight,
    'money': Icons.savings,
    'health': Icons.local_hospital,
    'shopping': Icons.shopping_bag,
    'repair': Icons.build,
    'internet': Icons.wifi,
    'insurance': Icons.verified_user,
    'debt': Icons.account_balance_wallet,
    'other': Icons.category,
  };

  static IconData getIcon(String iconName) {
    // Diese Funktion gibt das passende Icon zurück.
    // Wenn ein Icon-Name nicht existiert, nutzen wir ein Standard-Icon.
    return icons[iconName] ?? Icons.category;
  }
}