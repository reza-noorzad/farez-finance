import '../../core/supabase/supabase_client.dart';
import '../../shared/models/app_settings_model.dart';

class SettingsRepository {
  Future<AppSettingsModel> fetchOrCreateSettings() async {
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final existingRows = await AppSupabase.client
        .from('app_settings')
        .select()
        .eq('user_id', userId)
        .limit(1);

    if (existingRows.isNotEmpty) {
      return _settingsFromRow(existingRows.first);
    }

    final row = await AppSupabase.client
        .from('app_settings')
        .insert({
          'user_id': userId,
          'language': 'german',
          'currency_code': 'EUR',
        })
        .select()
        .single();

    return _settingsFromRow(row);
  }

  Future<AppSettingsModel> updateSettings(AppSettingsModel settings) async {
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('app_settings')
        .upsert({
          'user_id': userId,
          'language': settings.language.name,
          'currency_code': settings.currencyCode,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    return _settingsFromRow(row);
  }

  AppSettingsModel _settingsFromRow(Map<String, dynamic> row) {
    return AppSettingsModel(
      language: _languageFromString(row['language'] as String?),
      currencyCode: row['currency_code'] as String? ?? 'EUR',
    );
  }

  AppLanguage _languageFromString(String? value) {
    switch (value) {
      case 'english':
        return AppLanguage.english;
      case 'german':
      default:
        return AppLanguage.german;
    }
  }
}
