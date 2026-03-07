import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/services/fcm_device_sync.dart';

/// Serviço de autenticação e perfil (Supabase).
class AuthService {
  AuthService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.session == null) throw Exception('Falha ao fazer login');

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FcmDeviceSync.registerCurrentDevice();
    }

    return res;
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
    );
  }

  Future<void> signOut() async => _client.auth.signOut();

  @Deprecated('Tabela profiles removida. Usar clients/providers diretamente.')
  Future<Map<String, dynamic>?> getProfile() async => null;

  Future<String?> uploadAvatar(
    Uint8List bytes, {
    String? originalFileName,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuário não autenticado');
    String ext = 'png';
    if (originalFileName != null && originalFileName.contains('.')) {
      ext = originalFileName.split('.').last.toLowerCase();
    }
    final String path = '${user.id}/avatar.$ext';
    final bucket = _client.storage.from('avatars');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
    );
    return bucket.getPublicUrl(path);
  }

}
