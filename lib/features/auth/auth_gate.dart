import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/main_navigation.dart';
import '../../core/supabase/app_data_loader_service.dart';
import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import 'auth_page.dart';
import 'family_bootstrap_service.dart';
import '../profile/profile_repository.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<void>? _setupFuture;

  Future<void> _startAppSetup() {
    _setupFuture ??= _prepareLoggedInUser();
    return _setupFuture!;
  }

  Future<void> _prepareLoggedInUser() async {
    await ProfileRepository().fetchOrCreateProfile();

    await FamilyBootstrapService.ensureFamilyAndDefaultAccounts();

    FamilyContextService.clearCache();

    await AppDataLoaderService.loadInitialFinanceData();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AppSupabase.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = AppSupabase.client.auth.currentSession;

        if (session == null) {
          _setupFuture = null;
          FamilyContextService.clearCache();
          return const AuthPage();
        }

        return FutureBuilder<void>(
          future: _startAppSetup(),
          builder: (context, setupSnapshot) {
            if (setupSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (setupSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Fehler beim Laden der App-Daten:\n${setupSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              );
            }

            return const MainNavigation();
          },
        );
      },
    );
  }
}
