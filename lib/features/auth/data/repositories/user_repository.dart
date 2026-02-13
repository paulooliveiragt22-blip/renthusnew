import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/models/user.dart';

class UserRepository {

  UserRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<Client> getClientProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');
    final response = await _client
        .from('clients')
        .select('*')
        .eq('user_id', userId)
        .single();
    return Client.fromMap(response);
  }

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
      },);
      if (result is Map<String, dynamic>) return Client.fromMap(result);
      throw Exception('Resposta inválida do servidor');
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar perfil: ${e.message}');
    }
  }

  Future<Provider> getProviderProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');
    final response = await _client
        .from('providers')
        .select('*')
        .eq('user_id', userId)
        .single();
    return Provider.fromMap(response);
  }

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
      },);
      if (result is Map<String, dynamic>) return Provider.fromMap(result);
      throw Exception('Resposta inválida do servidor');
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar perfil: ${e.message}');
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');
    try {
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
    } catch (e) {
      throw Exception('Senha atual incorreta');
    }
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Erro ao atualizar senha: $e');
    }
    try {
      await _client.rpc('update_user_password', params: {
        'p_current_password': currentPassword,
        'p_new_password': newPassword,
      },);
    } catch (e) {
      if (kDebugMode) debugPrint('Aviso: Senha atualizada mas log falhou: $e');
    }
  }

  Future<void> deleteAccount({
    required String password,
    String? reason,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');
    try {
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );
    } catch (e) {
      throw Exception('Senha incorreta');
    }
    try {
      await _client.rpc('delete_user_account', params: {
        'p_reason': reason,
        'p_password': password,
      },);
    } catch (e) {
      throw Exception('Erro ao deletar conta: $e');
    }
    await _client.auth.signOut();
  }

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

  Future<UserRole> getUserRole() async {
    final isClientUser = await isClient();
    final isProviderUser = await isProvider();
    if (isClientUser && isProviderUser) return UserRole.both;
    if (isClientUser) return UserRole.client;
    if (isProviderUser) return UserRole.provider;
    return UserRole.none;
  }
}

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
