import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/core/exceptions/app_exceptions.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';
import 'package:renthus/features/chat/domain/models/message_model.dart';

/// Repository para Chat/Conversas
class ChatRepository {
  const ChatRepository(this._supabase);

  final SupabaseClient _supabase;

  // ==================== CONVERSATIONS ====================

  /// Listar conversas do usuário.
  /// Tenta view conversations_with_last_message; fallback para conversations.
  Future<List<Conversation>> getConversations(String userId) async {
    final orFilter = 'client_id.eq.$userId,provider_id.eq.$userId';
    try {
      final data = await _supabase
          .from('conversations_with_last_message')
          .select()
          .or(orFilter)
          .order('last_message_created_at', ascending: false);

      return data.map((e) => Conversation.fromMap(e)).toList();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('does not exist') || msg.contains('42p01')) {
        final data = await _supabase
            .from('conversations')
            .select()
            .or(orFilter)
            .order('created_at', ascending: false);
        return data.map((e) => Conversation.fromMap(e)).toList();
      }
      rethrow;
    }
  }

  /// Buscar conversa por ID
  Future<Conversation> getConversationById(String id) async {
    try {
      final data = await _supabase
          .from('conversations')
          .select()
          .eq('id', id)
          .single();

      return Conversation.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Buscar conversa por job
  Future<Conversation?> getConversationByJob(String jobId) async {
    try {
      final data = await _supabase
          .from('conversations')
          .select()
          .eq('job_id', jobId)
          .maybeSingle();

      if (data == null) return null;
      return Conversation.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Criar conversa
  Future<Conversation> createConversation({
    required String jobId,
    required String clientId,
    required String providerId,
  }) async {
    try {
      final data = await _supabase.from('conversations').insert({
        'job_id': jobId,
        'client_id': clientId,
        'provider_id': providerId,
      }).select().single();

      return Conversation.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Stream de conversas (real-time).
  /// Usa conversations_with_last_message se existir; senão conversations.
  Stream<List<Conversation>> watchConversations(String userId) {
    return _supabase
        .from('conversations_with_last_message')
        .stream(primaryKey: ['id'])
        .order('last_message_created_at', ascending: false)
        .map((data) => data
            .where((conv) =>
                conv['client_id'] == userId || conv['provider_id'] == userId,)
            .map((e) => Conversation.fromMap(e))
            .toList(),);
  }

  // ==================== MESSAGES ====================

  /// Listar mensagens de uma conversa
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return data.map((e) => Message.fromMap(e)).toList();
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Enviar mensagem
  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required String senderRole,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      final data = await _supabase.from('messages').insert({
        'conversation_id':  conversationId,
        'sender_id':        senderId,
        'sender_role':      senderRole,
        'content':          content,
        'type':             type.toJson(),
        'image_url':        imageUrl,
        'file_url':         fileUrl,
        'file_name':        fileName,
        // marca como lida pelo remetente imediatamente
        'read_by_client':   senderRole == 'client',
        'read_by_provider': senderRole == 'provider',
      }).select().single();

      return Message.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Marcar mensagens como lidas (usa read_by_client / read_by_provider)
  Future<void> markAsRead({
    required String conversationId,
    required String role,
  }) async {
    try {
      await _supabase.rpc('mark_messages_read', params: {
        'p_conversation_id': conversationId,
        'p_role': role,
      });
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Contar mensagens não lidas (1 query via RPC)
  Future<int> getUnreadCount(String userId) async {
    try {
      final result = await _supabase.rpc('get_unread_messages_count');
      return (result as int?) ?? 0;
    } catch (e) {
      return 0; // falha silenciosa — badge pode mostrar 0
    }
  }

  /// Stream de mensagens (real-time)
  Stream<List<Message>> watchMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => Message.fromMap(e)).toList());
  }

  /// Upload de imagem
  Future<String> uploadImage({
    required String conversationId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last.toLowerCase();
      final storagePath = 'chats/$conversationId/$timestamp.$extension';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

      await _supabase.storage.from('chat-images').uploadBinary(
            storagePath,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final url = _supabase.storage.from('chat-images').getPublicUrl(storagePath);
      return url;
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }
}
