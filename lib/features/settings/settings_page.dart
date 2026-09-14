import 'package:flutter/material.dart';

import '../../core/supabase/supabase_client.dart';
import '../../shared/models/app_settings_model.dart';
import '../../shared/widgets/section_title.dart';
import '../profile/profile_page.dart';
import 'app_settings_mock_data.dart';
import 'settings_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsRepository _settingsRepository = SettingsRepository();

  late AppSettingsModel _settings;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _currencies = const [
    'EUR',
    'USD',
    'GBP',
    'CHF',
    'TRY',
    'IRR',
  ];

  @override
  void initState() {
    super.initState();
    _settings = AppSettingsMockData.settings;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await _settingsRepository.fetchOrCreateSettings();

      AppSettingsMockData.updateSettings(settings);

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Einstellungen: $e';
        _isLoading = false;
      });
    }
  }

  String _languageLabel(AppLanguage language) {
    switch (language) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.german:
        return 'Deutsch';
    }
  }

  Future<void> _saveSettings(AppSettingsModel settings) async {
    setState(() {
      _settings = settings;
      _isSaving = true;
      _errorMessage = null;
    });

    AppSettingsMockData.updateSettings(settings);

    try {
      final savedSettings = await _settingsRepository.updateSettings(settings);

      AppSettingsMockData.updateSettings(savedSettings);

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = savedSettings;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Einstellungen konnten nicht gespeichert werden: $e';
        _isSaving = false;
      });
    }
  }

  void _updateLanguage(AppLanguage? language) {
    if (language == null) return;

    final newSettings = _settings.copyWith(language: language);
    _saveSettings(newSettings);
  }

  void _updateCurrency(String? currencyCode) {
    if (currencyCode == null) return;

    final newSettings = _settings.copyWith(currencyCode: currencyCode);
    _saveSettings(newSettings);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Abmelden'),
          content: const Text('Möchtest du dich wirklich abmelden?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abmelden'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await AppSupabase.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unbekannter Fehler',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null && !_isSaving) {
      return _buildErrorState();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh),
              tooltip: 'Aktualisieren',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSettings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle(title: 'Profil'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),
                title: const Text('Profil & Bild'),
                subtitle: const Text('Name, E-Mail und Profilbild verwalten.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SectionTitle(title: 'Language'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  RadioListTile<AppLanguage>(
                    title: const Text('English'),
                    subtitle: const Text('Use English in the app'),
                    value: AppLanguage.english,
                    groupValue: _settings.language,
                    onChanged: _isSaving ? null : _updateLanguage,
                  ),
                  RadioListTile<AppLanguage>(
                    title: const Text('Deutsch'),
                    subtitle: const Text('App auf Deutsch verwenden'),
                    value: AppLanguage.german,
                    groupValue: _settings.language,
                    onChanged: _isSaving ? null : _updateLanguage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Currency'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _settings.currencyCode,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: _currencies.map((currency) {
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              onChanged: _isSaving ? null : _updateCurrency,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Current Settings'),
                subtitle: Text(
                  'Language: ${_languageLabel(_settings.language)}\n'
                  'Currency: ${_settings.currencyCode}',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Diese Einstellungen werden jetzt dauerhaft in Supabase gespeichert.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Konto'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Abmelden'),
                subtitle: const Text('Von diesem Gerät abmelden.'),
                onTap: _signOut,
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}
