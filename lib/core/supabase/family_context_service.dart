import 'supabase_client.dart';

class FamilyContextService {
  static String? _cachedFamilyId;

  static String? get cachedFamilyId => _cachedFamilyId;

  static Future<String> getCurrentFamilyId() async {
    if (_cachedFamilyId != null) {
      return _cachedFamilyId!;
    }

    final user = AppSupabase.currentUser;

    if (user == null) {
      throw Exception('No logged in user.');
    }

    final response = await AppSupabase.client
        .from('family_members')
        .select('family_id')
        .eq('user_id', user.id)
        .limit(1)
        .single();

    final familyId = response['family_id'] as String?;

    if (familyId == null || familyId.isEmpty) {
      throw Exception('No family found for current user.');
    }

    _cachedFamilyId = familyId;
    return familyId;
  }

  static void clearCache() {
    _cachedFamilyId = null;
  }
}