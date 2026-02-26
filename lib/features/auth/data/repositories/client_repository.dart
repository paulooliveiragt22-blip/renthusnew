import 'package:supabase_flutter/supabase_flutter.dart';

class ClientRepository {

  ClientRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  User get _currentUser {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Nenhum usuário autenticado.');
    return user;
  }

  /// Perfil do cliente para home (endereço, nome, cidade)
  Future<Map<String, dynamic>?> getProfileForHome() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final res = await _client
        .from('clients')
        .select('address_street, address_number, full_name, city')
        .eq('id', user.id)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  /// Lê perfil do cliente logado via VIEW (sem tabela crua)
  Future<Map<String, dynamic>?> getMe() async {
    _currentUser; // garante auth
    final row = await _client.from('v_client_me').select().maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// Atualiza dados básicos do cliente via RPC (sem update direto em tabela)
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
    },);
  }

  /// Atualiza avatar via RPC (recomendado)
  Future<void> updateAvatarUrl(String avatarUrl) async {
    _currentUser;
    await _client.rpc('rpc_client_update_avatar', params: {
      'p_avatar_url': avatarUrl,
    },);
  }

  String get authUserId => _currentUser.id;
}
