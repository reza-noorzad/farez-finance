import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_gate.dart';

class FarezFinanceApp extends StatelessWidget {
  const FarezFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farez Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}