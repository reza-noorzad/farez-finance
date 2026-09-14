import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/supabase/supabase_client.dart';
import '../../shared/models/profile_model.dart';
import 'profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRepository _repository = ProfileRepository();
  final TextEditingController _displayNameController = TextEditingController();

  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _repository.fetchOrCreateProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _displayNameController.text = profile.displayName;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Profil konnte nicht geladen werden: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile({String? avatarUrl}) async {
    final displayName = _displayNameController.text.trim();

    if (displayName.isEmpty) {
      _showError('Bitte Namen eingeben.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final saved = await _repository.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl ?? _profile?.avatarUrl,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = saved;
        _isSaving = false;
      });

      _showMessage('Profil gespeichert.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError('Profil konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;

    input.click();

    await input.onChange.first;

    final file = input.files?.isEmpty == false ? input.files!.first : null;

    if (file == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final bytes = await _readFileBytes(file);
      final extension = _extensionFromFileName(file.name);

      final avatarUrl = await _repository.uploadAvatar(
        bytes: bytes,
        extension: extension,
      );

      await _saveProfile(avatarUrl: avatarUrl);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError('Bild konnte nicht hochgeladen werden: $e');
    }
  }

  Future<Uint8List> _readFileBytes(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final result = reader.result;

    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }

    if (result is Uint8List) {
      return result;
    }

    throw Exception('Datei konnte nicht gelesen werden.');
  }

  String _extensionFromFileName(String name) {
    final parts = name.split('.');

    if (parts.length < 2) {
      return 'jpg';
    }

    return parts.last.toLowerCase();
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final saved = await _repository.removeAvatar();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = saved;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError('Bild konnte nicht entfernt werden: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _profile?.email ?? AppSupabase.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundImage: _profile?.avatarUrl == null
                                  ? null
                                  : NetworkImage(_profile!.avatarUrl!),
                              child: _profile?.avatarUrl == null
                                  ? const Icon(Icons.person, size: 52)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed:
                                      _isSaving ? null : _pickAndUploadAvatar,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Bild ändern'),
                                ),
                                if (_profile?.avatarUrl != null)
                                  TextButton.icon(
                                    onPressed:
                                        _isSaving ? null : _removeAvatar,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Bild löschen'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'z.B. Reza',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : () => _saveProfile(),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Profil speichern'),
                    ),
                  ],
                ),
    );
  }
}
