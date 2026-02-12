import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/chat/data/providers/chat_providers.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';
import 'package:renthus/screens/chat_page.dart';

/// Tela de chats do cliente migrada para Riverpod.
class ClientChatsPage extends ConsumerWidget {
  const ClientChatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const roxo = Color(0xFF3B246B);
    final userId = ref.watch(currentUserIdProvider);
    final conversationsAsync = ref.watch(conversationsStreamProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: roxo,
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 18,
              ),
              child: const Text(
                'Chats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Erro ao carregar chats:\n$error',
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
                          'Você ainda não iniciou nenhum chat.\n'
                          'Quando aprovar um profissional, o chat aparece aqui.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 1),
                    itemBuilder: (context, index) {
                      final c = conversations[index];
                      final jobTitle =
                          (c.jobTitle?.trim().isNotEmpty == true)
                              ? c.jobTitle!
                              : 'Orçamento';
                      final jobDescription = '';
                      final lastMsg = c.lastMessage?.trim() ?? '';
                      String timeLabel = '';
                      if (c.lastMessageAt != null) {
                        final dt = c.lastMessageAt!.toLocal();
                        timeLabel =
                            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      }
                      final avatarLetter =
                          (c.providerName?.trim().isNotEmpty == true)
                              ? c.providerName!
                                  .trim()
                                  .characters
                                  .firstOrNull
                                  ?.toUpperCase() ??
                                  'P'
                              : 'P';

                      return Material(
                        color: index % 2 == 0
                            ? const Color(0xFFF7F7F7)
                            : Colors.white,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  conversationId: c.id,
                                  jobTitle: jobTitle,
                                  otherUserName:
                                      c.providerName ?? 'Profissional',
                                  currentUserId: userId,
                                  currentUserRole: 'client',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFD5C5F5),
                                  child: Text(
                                    avatarLetter,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3B246B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        jobTitle,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3B246B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (jobDescription.isNotEmpty)
                                        Text(
                                          jobDescription,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        )
                                      else
                                        const Text(
                                          'Profissional',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      if (lastMsg.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (timeLabel.isNotEmpty)
                                      Text(
                                        timeLabel,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
