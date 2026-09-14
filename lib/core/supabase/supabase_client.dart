import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  static SupabaseClient get client {
    return Supabase.instance.client;
  }

  static User? get currentUser {
    return client.auth.currentUser;
  }

  static String? get currentUserId {
    return currentUser?.id;
  }

  static bool get isLoggedIn {
    return currentUser != null;
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
