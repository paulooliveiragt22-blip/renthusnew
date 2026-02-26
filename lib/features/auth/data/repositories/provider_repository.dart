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

  /// Garante que existe registro em providers (idempotente)
  Future<void> ensureProfile() async {
    await _client.rpc('provider_ensure_profile');
  }

  /// Retorna roles do usuário (default_role: client | provider | both | null)
  Future<String?> getMyRoles() async {
    final res = await _client.rpc('get_my_roles');
    if (res is List && res.isNotEmpty) {
      final row = res.first as Map<String, dynamic>;
      return row['default_role'] as String?;
    }
    return null;
  }

  /// Retorna o perfil do prestador logado (VIEW v_provider_me)
  Future<Map<String, dynamic>?> getMe() async {
    _currentUser;
    final row = await _client.from('v_provider_me').select().maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// Garante profile e retorna getMe (para telas que precisam garantir registro)
  Future<Map<String, dynamic>?> getMeEnsured() async {
    try {
      await ensureProfile();
    } catch (_) {}
    return getMe();
  }

  /// Dados bancários do prestador (para tela de alterar conta bancária).
  /// Lê da tabela providers; RLS deve permitir SELECT onde user_id = auth.uid().
  Future<Map<String, dynamic>?> getProviderBankData() async {
    final uid = _currentUser.id;
    final row = await _client
        .from('providers')
        .select(
          'id, cpf, bank_code, bank_branch_number, bank_branch_check_digit, '
          'bank_account_number, bank_account_check_digit, bank_account_type, '
          'bank_holder_name, pagarme_recipient_id',
        )
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// Retorna provider_id (PK interno) a partir da view
  Future<String?> getMyProviderId() async {
    final row =
        await _client.from('v_provider_me').select('provider_id').maybeSingle();
    return row?['provider_id']?.toString();
  }

  /// Retorna se o prestador está verificado (verification_status = 'active')
  Future<bool> isVerified() async {
    final row = await _client
        .from('v_provider_me')
        .select('verification_status')
        .maybeSingle();
    return (row?['verification_status'] as String?) == 'active';
  }

  /// Retorna se onboarding foi concluído
  Future<bool> isOnboardingCompleted() async {
    final row = await _client
        .from('v_provider_me')
        .select('onboarding_completed')
        .maybeSingle();
    return (row?['onboarding_completed'] as bool?) ?? false;
  }

  /// Lista nomes dos serviços de um prestador (por provider_id)
  Future<List<String>> getServiceNamesByProviderId(String providerId) async {
    final rows = await _client
        .from('v_public_provider_services')
        .select('service_type_name')
        .eq('provider_id', providerId);

    final list = <String>[];
    for (final r in (rows as List<dynamic>)) {
      final m = Map<String, dynamic>.from(r as Map);
      final name = (m['service_type_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) list.add(name);
    }
    list.sort();
    return list;
  }

  /// Lista nomes dos serviços do prestador logado (chips)
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
    String? addressComplement,
  }) async {
    _currentUser;

    await _client.rpc(
      'rpc_provider_update_me',
      params: {
        'p_full_name': fullName,
        'p_phone': phone,
        'p_address_city': city,
        'p_address_state': state,
        'p_address_cep': cep,
        'p_address_street': addressStreet,
        'p_address_number': addressNumber,
        'p_address_district': addressDistrict,
        'p_address_complement': addressComplement,
      },
    );
  }

  /// Atualiza avatar do prestador via RPC
  Future<void> updateAvatarUrl(String avatarUrl) async {
    _currentUser;

    await _client.rpc(
      'rpc_provider_update_avatar',
      params: {
        'p_avatar_url': avatarUrl,
      },
    );
  }

  /// Helper: auth.uid()
  String get authUserId => _currentUser.id;

  /// Cancela conta do prestador
  Future<void> deleteAccount() async {
    await _client.rpc('rpc_provider_delete_account');
  }
}
