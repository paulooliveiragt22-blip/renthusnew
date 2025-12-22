import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_page.dart';

class ClientChatsPage extends StatefulWidget {
  const ClientChatsPage({super.key});

  @override
  State<ClientChatsPage> createState() => _ClientChatsPageState();
}

class _ClientChatsPageState extends State<ClientChatsPage> {
  final _supabase = Supabase.instance.client;

  /// Stream de conversas do cliente, ordenadas pela última mensagem
  Stream<List<Map<String, dynamic>>> _conversationStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // se por algum motivo não tiver usuário logado
      return const Stream.empty();
    }

    final userId = user.id;

    final stream = _supabase
        .from('conversation_with_last_message')
        .stream(primaryKey: ['id'])
        // app do CLIENTE: só conversas onde ele é client_id
        .eq('client_id', userId)
        .order('last_message_created_at', ascending: false);

    return stream.map(
      (rows) => List<Map<String, dynamic>>.from(rows as List),
    );
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            // Cabeçalho roxo
            Container(
              width: double.infinity,
              color: roxo,
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 16, bottom: 18),
              child: const Text(
                'Chats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Lista de conversas
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _conversationStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Erro ao carregar chats:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final conversations = snapshot.data ?? [];

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
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 1), // “linha” entre cards
                    itemBuilder: (context, index) {
                      final c = conversations[index];

                      final conversationId = c['id']?.toString() ?? '';

                      // Título do job (ou "Orçamento" se vier nulo)
                      final jobTitle = (c['job_title'] as String?)?.trim();
                      final titleText =
                          (jobTitle != null && jobTitle.isNotEmpty)
                              ? jobTitle
                              : 'Orçamento';

                      // Descrição do serviço (jobs.description -> job_description)
                      final rawDesc =
                          (c['job_description'] ?? c['description']) as String?;
                      final jobDescription =
                          (rawDesc ?? '').trim(); // nunca nulo aqui

                      // Última mensagem
                      final lastMsg =
                          (c['last_message_content'] as String?)?.trim() ?? '';

                      // Horário da última mensagem
                      DateTime? lastDate;
                      final createdStr =
                          c['last_message_created_at']?.toString();
                      if (createdStr != null) {
                        lastDate = DateTime.tryParse(createdStr)?.toLocal();
                      }
                      String timeLabel = '';
                      if (lastDate != null) {
                        final hh = lastDate.hour.toString().padLeft(2, '0');
                        final mm = lastDate.minute.toString().padLeft(2, '0');
                        timeLabel = '$hh:$mm';
                      }

                      // Letras do avatar (C de Cliente, P de Profissional, etc.)
                      final avatarLetter = (c['provider_name'] as String?)
                              ?.trim()
                              .characters
                              .firstOrNull
                              ?.toUpperCase() ??
                          'P';

                      return Material(
                        color: index % 2 == 0
                            ? const Color(0xFFF7F7F7)
                            : Colors.white,
                        child: InkWell(
                          onTap: () {
                            final user = _supabase.auth.currentUser;
                            if (user == null || conversationId.isEmpty) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  conversationId: conversationId,
                                  jobTitle: titleText,
                                  otherUserName:
                                      (c['provider_name'] as String?) ??
                                          'Profissional',
                                  currentUserId: user.id,
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
                                // Avatar
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFD5C5F5),
                                  child: Text(
                                    avatarLetter,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: roxo,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Título + descrição + última msg
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titleText,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: roxo,
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

                                // Horário + seta
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
