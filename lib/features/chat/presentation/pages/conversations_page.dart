import 'package:flutter/material.dart';

import 'package:renthus/core/utils/error_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/chat/data/providers/chat_providers.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';

/// Tela de conversas migrada para Riverpod.
class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conversas'),
          backgroundColor: const Color(0xFF3B246B),
        ),
        body: const Center(
          child: Text('Faça login para ver suas conversas.'),
        ),
      );
    }
    
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
        body: Center(child: Text(ErrorHandler.friendlyErrorMessage(error))),
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
                final title = (c.jobTitle?.trim().isNotEmpty == true)
                    ? c.jobTitle!
                    : 'Chat';
                final rawMsg = (c.lastMessage ?? '').trim();
                final lastMsg = rawMsg == '[imagem]'
                    ? '📷 Imagem'
                    : rawMsg.isEmpty
                        ? 'Sem mensagens ainda'
                        : rawMsg;
                final timeLabel = c.lastMessageTimeFormatted;
                final isClient = c.clientId == userId;
                final otherName = c.getOtherPersonName(userId);
                final otherPhoto = c.getOtherPersonPhoto(userId) ?? '';

                return ListTile(
                  leading: otherPhoto.isNotEmpty
                      ? CircleAvatar(
                          backgroundImage:
                              NetworkImage(otherPhoto),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.person, size: 18),
                        ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$otherName · $lastMsg',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: timeLabel.isNotEmpty
                      ? Text(
                          timeLabel,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  onTap: () {
                    context.pushChat({
                      'conversationId': c.id,
                      'jobTitle': title,
                      'otherUserName': otherName,
                      'currentUserId': userId,
                      'currentUserRole': isClient ? 'client' : 'provider',
                      'otherUserPhotoUrl':
                          otherPhoto.isEmpty ? null : otherPhoto,
                    });
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
