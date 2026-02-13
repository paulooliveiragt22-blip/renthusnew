// lib/services/auth_service.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de autenticação e perfil.
/// Compatível com supabase_flutter ^2.x
class AuthService {
  AuthService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Usuário logado (ou null se não estiver logado)
  User? get currentUser => _client.auth.currentUser;

  // ---------------------------------------------------------------------------
  // LOGIN / LOGOUT BÁSICO (se quiser usar depois nas telas de auth)
  // ---------------------------------------------------------------------------

  /// Faz login com email e senha.
  /// Lança Exception em caso de erro.
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.session == null) {
      throw Exception('Falha ao fazer login');
    }
    return res;
  }

  /// Cria usuário e já cria/atualiza o registro em `profiles`.
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'role': role,
      },
    );

    final user = res.user;
    if (user != null) {
      await _upsertProfile(
        id: user.id,
        name: name,
        role: role,
        email: email,
      );
    }

    return res;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // PERFIL (profiles) + AVATAR
  // ---------------------------------------------------------------------------

  /// Busca o perfil do usuário logado na tabela `profiles`.
  /// Retorna null se não achar.
  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final res = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (res == null) return null;

    if (res is Map<String, dynamic>) {
      return Map<String, dynamic>.from(res);
    }

    try {
      final data = (res as dynamic)['data'];
      if (data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    return null;
  }

  /// Atualiza o perfil do usuário logado.
  /// Campos opcionais que forem null não são enviados para o update.
  Future<Map<String, dynamic>?> updateProfile({
    required String name,
    String? phone,
    String? role,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }

    final Map<String, dynamic> updates = {
      'name': name,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (phone != null) updates['phone'] = phone;
    if (role != null) updates['role'] = role;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final res = await _client
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .maybeSingle();

    if (res == null) return null;

    if (res is Map<String, dynamic>) {
      return Map<String, dynamic>.from(res);
    }

    try {
      final data = (res as dynamic)['data'];
      if (data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    return null;
  }

  /// Faz upload do avatar no bucket `avatars` e retorna a URL pública.
  ///
  /// IMPORTANTE:
  /// - O *key* NÃO inclui o nome do bucket.
  ///   Ex.: `bc3a.../avatar.png` (✅)
  ///   e NÃO `avatars/bc3a.../avatar.png` (❌ InvalidKey)
  Future<String?> uploadAvatar(
    Uint8List bytes, {
    String? originalFileName,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }

    // Descobre a extensão (png/jpg) a partir do nome original
    String ext = 'png';
    if (originalFileName != null && originalFileName.contains('.')) {
      ext = originalFileName.split('.').last.toLowerCase();
    }

    // Caminho interno do arquivo dentro do bucket (SEM o nome do bucket)
    final String path = '${user.id}/avatar.$ext';

    final bucket = _client.storage.from('avatars');

    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: 'image/$ext',
      ),
    );

    // Se o bucket estiver como "Public", essa URL já é acessível
    final publicUrl = bucket.getPublicUrl(path);
    return publicUrl;
  }

  // ---------------------------------------------------------------------------
  // MÉTODO INTERNO para criar/atualizar profile na primeira vez
  // ---------------------------------------------------------------------------

  Future<void> _upsertProfile({
    required String id,
    required String name,
    required String role,
    required String email,
  }) async {
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', id)
        .maybeSingle();

    final payload = <String, dynamic>{
      'id': id,
      'name': name,
      'role': role,
      'email': email,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing == null) {
      payload['created_at'] = DateTime.now().toIso8601String();
      await _client.from('profiles').insert(payload);
    } else {
      await _client.from('profiles').update(payload).eq('id', id);
    }
  }
}
