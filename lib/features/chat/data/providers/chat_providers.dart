import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/cache_provider.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/chat/data/repositories/chat_repository.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';
import 'package:renthus/features/chat/domain/models/message_model.dart';

part 'chat_providers.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return ChatRepository(supabase);
}

@riverpod
Future<List<Conversation>> conversationsList(ConversationsListRef ref, String userId) async {
  final repository = ref.watch(chatRepositoryProvider);
  final cache = ref.watch(cacheServiceProvider);

  final cached = await cache.getConversations(userId);
  if (cached != null) {
    return cached
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  final conversations = await repository.getConversations(userId);
  await cache.saveConversations(
    userId,
    conversations.map((c) => c.toJson()).toList(),
  );
  return conversations;
}

@riverpod
Stream<List<Conversation>> conversationsStream(ConversationsStreamRef ref, String userId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchConversations(userId);
}

@riverpod
Future<List<Message>> messagesList(MessagesListRef ref, String conversationId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getMessages(conversationId);
}

@riverpod
Stream<List<Message>> messagesStream(MessagesStreamRef ref, String conversationId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchMessages(conversationId);
}

@riverpod
Future<int> unreadMessagesCount(UnreadMessagesCountRef ref, String userId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getUnreadCount(userId);
}

@riverpod
class ChatActions extends _$ChatActions {
  @override
  FutureOr<void> build() async {}

  Future<Message?> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
  }) async {
    state = const AsyncValue.loading();

    return await AsyncValue.guard(() async {
      final repository = ref.read(chatRepositoryProvider);
      final cache = ref.read(cacheServiceProvider);
      final msg = await repository.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        type: type,
        imageUrl: imageUrl,
      );
      await cache.clearConversations();
      ref.invalidate(conversationsListProvider);
      return msg;
    }).then((result) => result.value);
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    final repository = ref.read(chatRepositoryProvider);
    await repository.markAsRead(conversationId: conversationId, userId: userId);
  }
}
