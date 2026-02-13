import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositório responsável por conversar com:
/// - conversations
/// - messages
///
/// Objetivo: NÃO depender de tabela crua `providers`.
class ChatRepository {
  final SupabaseClient _client;

  ChatRepository._internal(this._client);

  factory ChatRepository([SupabaseClient? client]) =>
      ChatRepository._internal(client ?? Supabase.instance.client);

  ChatRepository.withClient(SupabaseClient client) : _client = client;

  // ---------------------------------------------------------------------------
  // UTIL: resolver provider_id (providers.id) sem acessar tabela crua
  // ---------------------------------------------------------------------------

  /// Converte o auth.user.id do prestador para o provider_id (providers.id)
  /// usando RPC.
  ///
  /// Requer RPC no banco: rpc_provider_id_from_user(p_user_id uuid) returns uuid
  ///
  /// Fallback: retorna o próprio providerAuthUserId para não quebrar enquanto
  /// a RPC não existir (mantém compatibilidade temporária).
  Future<String> resolveProviderIdFromAuth(String providerAuthUserId) async {
    try {
      final res = await _client.rpc(
        'rpc_provider_id_from_user',
        params: {'p_user_id': providerAuthUserId},
      );

      // res pode vir como String/uuid
      if (res == null) return providerAuthUserId;

      if (res is String && res.isNotEmpty) return res;
      return res.toString();
    } on PostgrestException {
      return providerAuthUserId;
    } catch (_) {
      return providerAuthUserId;
    }
  }

  /// Retorna uma lista de IDs possíveis para filtrar conversas.
  /// - Sempre inclui auth.uid() (userId)
  /// - Se existir provider_id na view v_provider_me, inclui também
  Future<List<String>> _conversationIdentityIds(String userId) async {
    final ids = <String>{userId};

    try {
      final me = await _client
          .from('v_provider_me')
          .select('provider_id')
          .maybeSingle();

      final providerId = me?['provider_id']?.toString();
      if (providerId != null && providerId.isNotEmpty) {
        ids.add(providerId);
      }
    } catch (_) {
      // se não tiver view ou policy, só ignora
    }

    return ids.toList();
  }

  // ===========================================================================
  // CONVERSATIONS
  // ===========================================================================

  /// Cria (ou retorna existente) conversa para um job específico
  /// entre [clientId] e [providerId].
  ///
  /// OBS: providerId pode vir como auth.user.id (do prestador) — vamos resolver
  /// para provider_id (providers.id) via RPC.
  Future<Map<String, dynamic>?> upsertConversationForJob({
    required String jobId,
    required String clientId,
    required String providerId, // pode ser auth.uid() do provider
    String? title,
  }) async {
    String safeTitle = (title ?? '').trim();
    if (safeTitle.isEmpty) safeTitle = 'Chat do serviço';

    final providerTableId = await resolveProviderIdFromAuth(providerId);

    // 1) Buscar conversa existente
    final existing = await _client
        .from('conversations')
        .select()
        .eq('job_id', jobId)
        .eq('client_id', clientId)
        .eq('provider_id', providerTableId)
        .maybeSingle();

    if (existing != null) {
      return Map<String, dynamic>.from(existing as Map);
    }

    // 2) Criar nova conversa
    final inserted = await _client
        .from('conversations')
        .insert({
          'job_id': jobId,
          'client_id': clientId,
          'provider_id': providerTableId,
          'title': safeTitle,
          'status': 'open',
        })
        .select()
        .maybeSingle();

    if (inserted == null) return null;
    return Map<String, dynamic>.from(inserted as Map);
  }

  /// Lista conversas do usuário (cliente ou prestador).
  /// Tenta usar view `conversation_with_last_message`.
  /// Se não existir, cai para `conversations`.
  Future<List<Map<String, dynamic>>> fetchConversationsForUser(
    String userId,
  ) async {
    final ids = await _conversationIdentityIds(userId);

    // monta o OR para client_id/provid_id com 1 ou 2 ids
    final orParts = <String>[];
    for (final id in ids) {
      orParts.add('client_id.eq.$id');
      orParts.add('provider_id.eq.$id');
    }
    final orFilter = orParts.join(',');

    try {
      final rows = await _client
          .from('conversation_with_last_message')
          .select()
          .or(orFilter)
          .order('last_message_created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final isMissingRelation =
          e.code == '42P01' || msg.contains('does not exist');

      if (!isMissingRelation) rethrow;

      final rows = await _client
          .from('conversations')
          .select()
          .or(orFilter)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows as List);
    }
  }

  // ===========================================================================
  // MESSAGES
  // ===========================================================================

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole, // "client" ou "provider"
    required String content,
    String type = 'text', // 'text' ou 'image'
    String? imageUrl,
  }) async {
    final trimmed = content.trim();

    if (type == 'text' && trimmed.isEmpty) return;

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'type': type,
      'content': trimmed.isEmpty ? '[imagem]' : trimmed,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
    final stream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return stream.map((rows) => List<Map<String, dynamic>>.from(rows as List));
  }
}
