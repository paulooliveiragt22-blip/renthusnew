import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositório legado responsável por conversar com:
/// - conversations
/// - messages
///
/// Objetivo: NÃO depender de tabela crua `providers`.
/// Usado por jobs (upsertConversationForJob, etc).
class LegacyChatRepository {

  factory LegacyChatRepository([SupabaseClient? client]) =>
      LegacyChatRepository._internal(client ?? Supabase.instance.client);

  LegacyChatRepository._internal(this._client);

  LegacyChatRepository.withClient(SupabaseClient client) : _client = client;
  final SupabaseClient _client;

  Future<String> resolveProviderIdFromAuth(String providerAuthUserId) async {
    try {
      final res = await _client.rpc(
        'rpc_provider_id_from_user',
        params: {'p_user_id': providerAuthUserId},
      );

      if (res == null) return providerAuthUserId;

      if (res is String && res.isNotEmpty) return res;
      return res.toString();
    } on PostgrestException {
      return providerAuthUserId;
    } catch (_) {
      return providerAuthUserId;
    }
  }

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
    } catch (_) {}

    return ids.toList();
  }

  Future<Map<String, dynamic>?> upsertConversationForJob({
    required String jobId,
    required String clientId,
    required String providerId,
    String? title,
  }) async {
    String safeTitle = (title ?? '').trim();
    if (safeTitle.isEmpty) safeTitle = 'Chat do serviço';

    final providerTableId = await resolveProviderIdFromAuth(providerId);

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

  Future<List<Map<String, dynamic>>> fetchConversationsForUser(
    String userId,
  ) async {
    final ids = await _conversationIdentityIds(userId);

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

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String content,
    String type = 'text',
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
