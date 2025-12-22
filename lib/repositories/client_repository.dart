import 'package:supabase_flutter/supabase_flutter.dart';

class ClientRepository {
  final SupabaseClient _client;

  ClientRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  User get _currentUser {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Nenhum usuário autenticado.');
    return user;
  }

  /// Lê perfil do cliente logado via VIEW (sem tabela crua)
  Future<Map<String, dynamic>?> getMe() async {
    _currentUser; // garante auth
    final row = await _client.from('v_client_me').select().maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// Atualiza dados básicos do cliente via RPC (sem update direto em tabela)
  /// Crie no banco: rpc_client_update_me(p_full_name text, p_phone text, p_city text, p_address_zip_code text, ...)
  Future<void> updateMe({
    String? fullName,
    String? phone,
    String? city,
    String? addressZipCode,
    String? addressStreet,
    String? addressNumber,
    String? addressDistrict,
    String? addressState,
  }) async {
    _currentUser;

    await _client.rpc('rpc_client_update_me', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_city': city,
      'p_address_zip_code': addressZipCode,
      'p_address_street': addressStreet,
      'p_address_number': addressNumber,
      'p_address_district': addressDistrict,
      'p_address_state': addressState,
    });
  }

  /// Atualiza avatar via RPC (recomendado)
  Future<void> updateAvatarUrl(String avatarUrl) async {
    _currentUser;

    await _client.rpc('rpc_client_update_avatar', params: {
      'p_avatar_url': avatarUrl,
    });
  }

  /// Helper: retorna o auth user id (se precisar)
  String get authUserId => _currentUser.id;
}
