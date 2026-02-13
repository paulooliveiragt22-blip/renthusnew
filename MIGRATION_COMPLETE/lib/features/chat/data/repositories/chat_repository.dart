import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/core/exceptions/app_exceptions.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';
import 'package:renthus/features/chat/domain/models/message_model.dart';

/// Repository para Chat/Conversas
class ChatRepository {
  const ChatRepository(this._supabase);

  final SupabaseClient _supabase;

  // ==================== CONVERSATIONS ====================

  /// Listar conversas do usuário
  Future<List<Conversation>> getConversations(String userId) async {
    try {
      final data = await _supabase
          .from('conversations')
          .select()
          .or('client_id.eq.$userId,provider_id.eq.$userId')
          .order('last_message_at', ascending: false);

      return data.map((e) => Conversation.fromMap(e)).toList();
    } catch (e) {
      throw parseSupabaseException(e);
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

  /// Stream de conversas (real-time)
  Stream<List<Conversation>> watchConversations(String userId) {
    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
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
    MessageType type = MessageType.text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      final data = await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'type': type.toJson(),
        'image_url': imageUrl,
        'file_url': fileUrl,
        'file_name': fileName,
      }).select().single();

      return Message.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Marcar mensagens como lidas
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Contar mensagens não lidas
  Future<int> getUnreadCount(String userId) async {
    try {
      // Busca conversas do usuário
      final conversations = await _supabase
          .from('conversations')
          .select('id')
          .or('client_id.eq.$userId,provider_id.eq.$userId');

      if (conversations.isEmpty) return 0;

      final conversationIds =
          conversations.map((c) => c['id'] as String).toList();

      // Conta mensagens não lidas
      final count = await _supabase
          .from('messages')
          .select('id', const FetchOptions(count: CountOption.exact))
          .inFilter('conversation_id', conversationIds)
          .neq('sender_id', userId)
          .eq('is_read', false);

      return count.count ?? 0;
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Stream de mensagens (real-time)
  Stream<List<Message>> watchMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
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
      final extension = fileName.split('.').last;
      final storagePath = 'chats/$conversationId/$timestamp.$extension';

      await _supabase.storage.from('chat-images').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
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
