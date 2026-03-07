import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:renthus/core/exceptions/app_exceptions.dart' show parseSupabaseException, AuthException;
import 'package:renthus/features/profile/domain/models/user_profile_model.dart';

/// Repository para operações de perfil
class ProfileRepository {
  const ProfileRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Buscar perfil do usuário atual
  Future<UserProfile> getProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AuthException('Usuário não autenticado');
      }

      final data = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      return UserProfile.fromJson({
        ...data,
        'email': user.email, // Email vem do auth
      });
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Atualizar perfil
  Future<UserProfile> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? role,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (role != null) updates['role'] = role;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase.from('users').update(updates).eq('id', userId);

      return await getProfile();
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Upload de avatar
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      // Nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final storagePath = '$userId/$timestamp.$extension';

      // Upload no bucket 'avatars'
      await _supabase.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Retorna URL pública
      final url = _supabase.storage.from('avatars').getPublicUrl(storagePath);

      return url;
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Deletar avatar antigo
  Future<void> deleteAvatar(String avatarUrl) async {
    try {
      // Extrai o path do storage da URL
      final uri = Uri.parse(avatarUrl);
      final path = uri.pathSegments.last;

      await _supabase.storage.from('avatars').remove([path]);
    } catch (e) {
      // Ignora erros ao deletar (avatar pode não existir)
      debugPrint('Erro ao deletar avatar: $e');
    }
  }
}
