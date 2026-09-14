import '../../core/supabase/supabase_client.dart';

class FamilyBootstrapService {
  static Future<String> ensureFamilyAndDefaultAccounts() async {
    final user = AppSupabase.currentUser;

    if (user == null) {
      throw Exception('No logged in user.');
    }

    final familyId = await AppSupabase.client.rpc(
      'bootstrap_finance_family',
    );

    if (familyId == null) {
      throw Exception('Family konnte nicht erstellt werden.');
    }

    return familyId.toString();
  }
}