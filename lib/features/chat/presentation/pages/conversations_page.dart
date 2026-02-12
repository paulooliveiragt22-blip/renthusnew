import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/chat/data/providers/chat_providers.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';
import 'package:renthus/screens/chat_page.dart';

/// Tela de conversas migrada para Riverpod.
class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final conversationsAsync = ref.watch(conversationsStreamProvider(userId));

    return conversationsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Conversas'),
          backgroundColor: const Color(0xFF3B246B),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Conversas'),
          backgroundColor: const Color(0xFF3B246B),
        ),
        body: Center(child: Text('$error')),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Conversas'),
              backgroundColor: const Color(0xFF3B246B),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Você ainda não tem conversas.\n'
                  'Aparecerão aqui depois que você falar com um prestador.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Conversas'),
            backgroundColor: const Color(0xFF3B246B),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(conversationsStreamProvider(userId));
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = items[index];
                final title =
                    (c.jobTitle?.trim().isNotEmpty == true) ? c.jobTitle! : 'Chat';
                final lastMsg =
                    (c.lastMessage ?? '').trim().isEmpty
                        ? 'Sem mensagens ainda'
                        : c.lastMessage!;
                final lastAt = c.lastMessageAt;
                final dateText = lastAt != null
                    ? '${lastAt.toLocal().toString().split('T').first}'
                    : '';

                final isClient = c.clientId == userId;
                final otherName = isClient ? 'Prestador' : 'Cliente';

                String subtitle = lastMsg;
                if (lastMsg.length > 60) {
                  subtitle = '${lastMsg.substring(0, 57)}...';
                }

                return ListTile(
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: dateText.isNotEmpty
                      ? Text(
                          dateText,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          conversationId: c.id,
                          jobTitle: title,
                          otherUserName: otherName,
                          currentUserId: userId,
                          currentUserRole: isClient ? 'client' : 'provider',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
