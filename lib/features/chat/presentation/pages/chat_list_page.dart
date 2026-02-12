import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/chat/data/providers/chat_providers.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';
import 'package:renthus/screens/chat_page.dart';

/// Lista de chats (cliente ou prestador) migrada para Riverpod.
class ChatListPage extends ConsumerWidget {
  final bool isClient;

  const ChatListPage({
    super.key,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final conversationsAsync = ref.watch(conversationsStreamProvider(userId));
    final title = isClient ? 'Meus chats' : 'Chats com clientes';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF3B246B),
        foregroundColor: Colors.white,
      ),
      body: conversationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Erro ao carregar conversas:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Você ainda não tem conversas.\n'
                  'Quando um serviço for iniciado, o chat aparecerá aqui.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(conversationsStreamProvider(userId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final c = conversations[index];
                return _ConversationCard(
                  conversation: c,
                  userId: userId,
                  isClient: isClient,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final String userId;
  final bool isClient;

  const _ConversationCard({
    required this.conversation,
    required this.userId,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context) {
    final title = (conversation.jobTitle?.trim().isNotEmpty == true)
        ? conversation.jobTitle!
        : 'Chat do serviço';
    final lastMessage = conversation.lastMessage?.trim() ?? '';
    final timeLabel = conversation.lastMessageAt != null
        ? _formatTime(conversation.lastMessageAt!)
        : '';
    final hasUnread = conversation.hasUnread;
    final unreadCount = conversation.unreadCount;
    final otherName = conversation.getOtherPersonName(userId);
    final isLocked = !conversation.isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: conversation.id,
                jobTitle: title,
                otherUserName: otherName,
                currentUserId: userId,
                currentUserRole: isClient ? 'client' : 'provider',
                isChatLocked: isLocked,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF3B246B).withOpacity(0.1),
          child: Icon(
            Icons.person,
            color: const Color(0xFF3B246B).withOpacity(0.8),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: lastMessage.isEmpty
            ? null
            : Text(
                lastMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (timeLabel.isNotEmpty)
              Text(
                timeLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (hasUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
