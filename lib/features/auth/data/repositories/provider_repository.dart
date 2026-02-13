import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderRepository {
  ProviderRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User get _currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Nenhum usuário autenticado.');
    }
    return user;
  }

  /// Retorna o perfil do prestador logado (VIEW v_provider_me)
  Future<Map<String, dynamic>?> getMe() async {
    _currentUser;
    final row = await _client.from('v_provider_me').select().maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// Retorna provider_id (PK interno) a partir da view
  Future<String?> getMyProviderId() async {
    final row =
        await _client.from('v_provider_me').select('provider_id').maybeSingle();
    return row?['provider_id']?.toString();
  }

  /// Retorna se o prestador está verificado (flag da view)
  Future<bool> isVerified() async {
    final row =
        await _client.from('v_provider_me').select('is_verified').maybeSingle();
    return (row?['is_verified'] as bool?) ?? false;
  }

  /// Retorna se onboarding foi concluído
  Future<bool> isOnboardingCompleted() async {
    final row = await _client
        .from('v_provider_me')
        .select('onboarding_completed')
        .maybeSingle();
    return (row?['onboarding_completed'] as bool?) ?? false;
  }

  /// Lista nomes dos serviços do prestador (chips)
  Future<List<String>> getMyServiceNames() async {
    final providerId = await getMyProviderId();
    if (providerId == null) return [];

    final rows = await _client
        .from('v_public_provider_services')
        .select('service_type_name')
        .eq('provider_id', providerId);

    final list = <String>[];
    for (final r in (rows as List<dynamic>)) {
      final m = Map<String, dynamic>.from(r as Map);
      final name = (m['service_type_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        list.add(name);
      }
    }

    list.sort();
    return list;
  }

  /// Atualiza dados do prestador via RPC
  Future<void> updateMe({
    String? fullName,
    String? phone,
    String? city,
    String? state,
    String? cep,
    String? addressStreet,
    String? addressNumber,
    String? addressDistrict,
  }) async {
    _currentUser;

    await _client.rpc('rpc_provider_update_me', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_city': city,
      'p_state': state,
      'p_cep': cep,
      'p_address_street': addressStreet,
      'p_address_number': addressNumber,
      'p_address_district': addressDistrict,
    },);
  }

  /// Atualiza avatar do prestador via RPC
  Future<void> updateAvatarUrl(String avatarUrl) async {
    _currentUser;

    await _client.rpc('rpc_provider_update_avatar', params: {
      'p_avatar_url': avatarUrl,
    },);
  }

  /// Helper: auth.uid()
  String get authUserId => _currentUser.id;
}
