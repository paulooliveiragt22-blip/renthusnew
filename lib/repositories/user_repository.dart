// lib/repositories/user_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

/// Repository para operações de usuário (Cliente e Prestador)
///
/// ✅ Type-safe (usa models tipados)
/// ✅ Seguro (usa RPCs, não acesso direto)
/// ✅ Validado (validações no backend)
/// ✅ Auditado (logs automáticos)
class UserRepository {
  final SupabaseClient _client;

  UserRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ========================================
  // CLIENT OPERATIONS
  // ========================================

  /// Buscar perfil do cliente atual
  Future<Client> getClientProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    final response = await _client
        .from('clients')
        .select('*')
        .eq('user_id', userId)
        .single();

    return Client.fromMap(response);
  }

  /// Atualizar perfil do cliente
  ///
  /// Usa RPC para garantir segurança e validações
  Future<Client> updateClientProfile({
    String? name,
    String? phone,
    String? cpf,
    String? addressStreet,
    String? addressNumber,
    String? addressDistrict,
    String? city,
    String? state,
    String? addressZipCode,
    String? photoUrl,
  }) async {
    try {
      final result = await _client.rpc('update_client_profile', params: {
        'p_name': name,
        'p_phone': phone,
        'p_cpf': cpf,
        'p_address_street': addressStreet,
        'p_address_number': addressNumber,
        'p_address_district': addressDistrict,
        'p_city': city,
        'p_state': state,
        'p_address_zip_code': addressZipCode,
        'p_photo_url': photoUrl,
      });

      // RPC retorna JSON, converter para Client
      if (result is Map<String, dynamic>) {
        return Client.fromMap(result);
      }

      throw Exception('Resposta inválida do servidor');
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar perfil: ${e.message}');
    }
  }

  // ========================================
  // PROVIDER OPERATIONS
  // ========================================

  /// Buscar perfil do prestador atual
  Future<Provider> getProviderProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    final response = await _client
        .from('providers')
        .select('*')
        .eq('user_id', userId)
        .single();

    return Provider.fromMap(response);
  }

  /// Atualizar perfil do prestador
  ///
  /// Usa RPC para garantir segurança e validações
  Future<Provider> updateProviderProfile({
    String? name,
    String? phone,
    String? cpf,
    String? cnpj,
    String? bio,
    String? addressStreet,
    String? addressNumber,
    String? addressDistrict,
    String? city,
    String? state,
    String? addressZipCode,
    String? photoUrl,
    bool? phoneVisibility,
    bool? emailVisibility,
    bool? addressVisibility,
  }) async {
    try {
      final result = await _client.rpc('update_provider_profile', params: {
        'p_name': name,
        'p_phone': phone,
        'p_cpf': cpf,
        'p_cnpj': cnpj,
        'p_bio': bio,
        'p_address_street': addressStreet,
        'p_address_number': addressNumber,
        'p_address_district': addressDistrict,
        'p_city': city,
        'p_state': state,
        'p_address_zip_code': addressZipCode,
        'p_photo_url': photoUrl,
        'p_phone_visibility': phoneVisibility,
        'p_email_visibility': emailVisibility,
        'p_address_visibility': addressVisibility,
      });

      if (result is Map<String, dynamic>) {
        return Provider.fromMap(result);
      }

      throw Exception('Resposta inválida do servidor');
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar perfil: ${e.message}');
    }
  }

  // ========================================
  // PASSWORD & ACCOUNT
  // ========================================

  /// Atualizar senha do usuário
  ///
  /// Processo:
  /// 1. Verificar senha atual (re-autenticar)
  /// 2. Atualizar via Supabase Auth
  /// 3. Logar mudança via RPC
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }

    // 1. Verificar senha atual (re-autenticar)
    try {
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
    } catch (e) {
      throw Exception('Senha atual incorreta');
    }

    // 2. Atualizar senha
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Erro ao atualizar senha: $e');
    }

    // 3. Logar mudança via RPC
    try {
      await _client.rpc('update_user_password', params: {
        'p_current_password': currentPassword,
        'p_new_password': newPassword,
      });
    } catch (e) {
      // Log falhou, mas senha foi atualizada
      print('Aviso: Senha atualizada mas log falhou: $e');
    }
  }

  /// Deletar conta do usuário (soft delete)
  ///
  /// Aviso: Operação irreversível!
  Future<void> deleteAccount({
    required String password,
    String? reason,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }

    // 1. Verificar senha (re-autenticar)
    try {
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );
    } catch (e) {
      throw Exception('Senha incorreta');
    }

    // 2. Soft delete via RPC
    try {
      await _client.rpc('delete_user_account', params: {
        'p_reason': reason,
        'p_password': password,
      });
    } catch (e) {
      throw Exception('Erro ao deletar conta: $e');
    }

    // 3. Sign out
    await _client.auth.signOut();
  }

  // ========================================
  // HELPER METHODS
  // ========================================

  /// Verificar se o usuário é cliente
  Future<bool> isClient() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final result = await _client
        .from('clients')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    return result != null;
  }

  /// Verificar se o usuário é prestador
  Future<bool> isProvider() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final result = await _client
        .from('providers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    return result != null;
  }

  /// Obter role do usuário
  Future<UserRole> getUserRole() async {
    final isClientUser = await isClient();
    final isProviderUser = await isProvider();

    if (isClientUser && isProviderUser) {
      return UserRole.both;
    } else if (isClientUser) {
      return UserRole.client;
    } else if (isProviderUser) {
      return UserRole.provider;
    } else {
      return UserRole.none;
    }
  }
}

/// Enum para role do usuário
enum UserRole {
  client,
  provider,
  both,
  none;

  String get displayName {
    switch (this) {
      case UserRole.client:
        return 'Cliente';
      case UserRole.provider:
        return 'Prestador';
      case UserRole.both:
        return 'Cliente e Prestador';
      case UserRole.none:
        return 'Não definido';
    }
  }
}
