import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  ChatRepository();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // HELPERS: nomes das views
  // ---------------------------------------------------------------------------

  String _clientChatsView(bool isClient) =>
      isClient ? 'v_client_chats' : 'v_provider_chats';

  String _chatHeaderView(bool isClient) =>
      isClient ? 'v_client_chat_header' : 'v_provider_chat_header';

  String _messagesView(bool isClient) => isClient
      ? 'v_client_conversation_messages'
      : 'v_provider_conversation_messages';

  // ===========================================================================
  // CHATS (LISTA)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> fetchChats({
    required bool isClient,
  }) async {
    final rows = await _client.from(_clientChatsView(isClient)).select('''
          conversation_id,
          job_code,
          job_description,
          provider_full_name,
          clients_full_name,
          provider_avatar_url,
          client_avatar_url,
          display_name,
          display_avatar_url,
          last_message_content,
          last_message_created_at
        ''').order('last_message_created_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ===========================================================================
  // HEADER DO CHAT
  // ===========================================================================

  Future<Map<String, dynamic>> fetchChatHeader({
    required String conversationId,
    required bool isClient,
  }) async {
    final row = await _client.from(_chatHeaderView(isClient)).select('''
          conversation_id,
          job_code,
          job_description,
          header_title,
          header_subtitle,
          header_avatar_url
        ''').eq('conversation_id', conversationId).maybeSingle();

    if (row == null) {
      throw Exception('Chat header não encontrado');
    }

    return (row as Map).cast<String, dynamic>();
  }

  // ===========================================================================
  // MESSAGES (VIEW)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> fetchMessages({
    required String conversationId,
    required bool isClient,
    int limit = 200,
  }) async {
    final rows = await _client
        .from(_messagesView(isClient))
        .select('''
          id,
          sender_id,
          sender_role,
          content,
          type,
          image_url,
          created_at
        ''')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ===========================================================================
  // STREAM (Realtime como gatilho, leitura via VIEW)
  // ===========================================================================

  Stream<List<Map<String, dynamic>>> streamMessagesView({
    required String conversationId,
    required bool isClient,
  }) {
    late final StreamController<List<Map<String, dynamic>>> controller;
    RealtimeChannel? channel;
    bool disposed = false;
    bool fetching = false;

    Future<void> emitNow() async {
      if (fetching) return;
      fetching = true;

      try {
        final data = await fetchMessages(
          conversationId: conversationId,
          isClient: isClient,
        );
        if (!disposed) controller.add(data);
      } catch (_) {
        // não quebra o stream
      } finally {
        fetching = false;
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () async {
        await emitNow();

        channel = _client
            .channel('chat:$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (_) async => await emitNow(),
            )
            .subscribe();
      },
      onCancel: () async {
        disposed = true;
        if (channel != null) {
          await _client.removeChannel(channel!);
        }
      },
    );

    return controller.stream;
  }

  // ===========================================================================
  // SEND MESSAGE (RPC)
  // ===========================================================================

  Future<void> sendMessageViaRpc({
    required String conversationId,
    required String senderRole, // 'client' | 'provider'
    required String content,
    String type = 'text',
    String? imageUrl,
  }) async {
    await _client.rpc(
      'send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_sender_role': senderRole,
        'p_content': content,
        'p_type': type,
        'p_image_url': imageUrl,
      },
    );
  }

  // ===========================================================================
  // CONVERSATION (UPSERT VIA RPC)  ✅ AQUI ESTÁ A CORREÇÃO
  // ===========================================================================

  /// Garante que exista uma conversa para o job + provider
  /// Retorna conversation_id
  Future<String> upsertConversationForJob({
    required String jobId,
    required String providerId,
  }) async {
    final res = await _client.rpc(
      'upsert_conversation_for_job',
      params: {
        'p_job_id': jobId,
        'p_provider_id': providerId,
      },
    );

    if (res == null) {
      throw Exception('Não foi possível criar/obter a conversa');
    }

    return res.toString();
  }
}
