import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';
import '../../shared/models/profile_model.dart';

class ProfileRepository {
  Future<ProfileModel> fetchOrCreateProfile() async {
    final user = AppSupabase.currentUser;

    if (user == null) {
      throw Exception('No logged in user.');
    }

    final existingRows = await AppSupabase.client
        .from('profiles')
        .select()
        .eq('user_id', user.id)
        .limit(1);

    if (existingRows is List && existingRows.isNotEmpty) {
      return _profileFromRow(existingRows.first as Map<String, dynamic>);
    }

    final email = user.email ?? '';
    final defaultName = _defaultNameFromEmail(email);

    final row = await AppSupabase.client
        .from('profiles')
        .insert({
          'user_id': user.id,
          'email': email,
          'display_name': defaultName,
          'avatar_url': null,
        })
        .select()
        .single();

    return _profileFromRow(row);
  }

  Future<ProfileModel> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    final user = AppSupabase.currentUser;

    if (user == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('profiles')
        .update({
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id)
        .select()
        .single();

    return _profileFromRow(row);
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
  }) async {
    final user = AppSupabase.currentUser;

    if (user == null) {
      throw Exception('No logged in user.');
    }

    final safeExtension = extension.replaceAll('.', '').toLowerCase();
    final path = '${user.id}/profile.$safeExtension';
    final contentType = _contentTypeForExtension(safeExtension);

    await AppSupabase.client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    final publicUrl = AppSupabase.client.storage.from('avatars').getPublicUrl(path);

    // cache busting for browser image refresh
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<ProfileModel> removeAvatar() async {
    final current = await fetchOrCreateProfile();

    return updateProfile(
      displayName: current.displayName,
      avatarUrl: null,
    );
  }

  ProfileModel _profileFromRow(Map<String, dynamic> row) {
    return ProfileModel(
      userId: row['user_id'] as String,
      email: row['email'] as String? ?? '',
      displayName: row['display_name'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      updatedAt: _toDateTime(row['updated_at']) ?? DateTime.now(),
    );
  }

  String _defaultNameFromEmail(String email) {
    if (email.isEmpty || !email.contains('@')) {
      return 'Benutzer';
    }

    return email.split('@').first;
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}
