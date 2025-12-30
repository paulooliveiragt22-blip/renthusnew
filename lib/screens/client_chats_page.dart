import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/chat_repository.dart';
import 'chat_page.dart';

class ClientChatsPage extends StatefulWidget {
  const ClientChatsPage({super.key});

  @override
  State<ClientChatsPage> createState() => _ClientChatsPageState();
}

class _ClientChatsPageState extends State<ClientChatsPage> {
  final _supabase = Supabase.instance.client;
  final _chatRepo = ChatRepository();

  static const roxo = Color(0xFF3B246B);

  StreamController<List<Map<String, dynamic>>>? _controller;
  RealtimeChannel? _channelMessages;
  RealtimeChannel? _channelConversations;

  bool _started = false;

  bool _emitting = false;
  Timer? _debounce;

  Future<List<Map<String, dynamic>>> _fetchChats() async {
    // ✅ padrão: tudo via repository (que usa v_client_chats)
    return _chatRepo.fetchChats(isClient: true);
  }

  Stream<List<Map<String, dynamic>>> _chatsStream() {
    if (_started) return _controller!.stream;
    _started = true;

    _controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () async {
        await _emitNow();

        // ✅ Gatilho: qualquer mudança em messages pode alterar "última mensagem"
        _channelMessages = _supabase
            .channel('client-chats:messages')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              callback: (_) => _scheduleEmit(),
            )
            .subscribe();

        // ✅ Gatilho: mudanças em conversations (caso RPC atualize campos da conversa)
        _channelConversations = _supabase
            .channel('client-chats:conversations')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'conversations',
              callback: (_) => _scheduleEmit(),
            )
            .subscribe();
      },
    );

    return _controller!.stream;
  }

  void _scheduleEmit() {
    // debounce para não refazer select 20x em sequência
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await _emitNow();
    });
  }

  Future<void> _emitNow() async {
    if (_emitting) return;
    _emitting = true;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _controller?.add(const []);
        return;
      }

      final chats = await _fetchChats();
      _controller?.add(chats);
    } catch (e) {
      debugPrint('Erro ao buscar chats (v_client_chats via repo): $e');
      // não derruba stream
    } finally {
      _emitting = false;
    }
  }

  Future<void> _disposeChannels() async {
    try {
      if (_channelMessages != null) {
        await _supabase.removeChannel(_channelMessages!);
        _channelMessages = null;
      }
      if (_channelConversations != null) {
        await _supabase.removeChannel(_channelConversations!);
        _channelConversations = null;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _disposeChannels();
    _controller?.close();
    super.dispose();
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _firstLetter(String name) {
    final s = name.trim();
    if (s.isEmpty) return 'P';
    return s.substring(0, 1).toUpperCase();
  }

  Widget _avatar(String? url, String fallbackLetter) {
    final u = (url ?? '').trim();
    if (u.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(u),
        onBackgroundImageError: (_, __) {},
        backgroundColor: const Color(0xFFD5C5F5),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFD5C5F5),
      child: Text(
        fallbackLetter,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: roxo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chatsStream(),
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
                    separatorBuilder: (_, __) => const SizedBox(height: 1),
                    itemBuilder: (context, index) {
                      final c = conversations[index];

                      final conversationId =
                          c['conversation_id']?.toString() ?? '';
                      if (conversationId.isEmpty)
                        return const SizedBox.shrink();

                      // ✅ Pedido #job_code
                      final jobCode = (c['job_code'] as String?)?.trim() ?? '';
                      final pedidoLabel =
                          jobCode.isNotEmpty ? 'Pedido #$jobCode' : 'Pedido';

                      // ✅ jobs.description
                      final jobDescription =
                          (c['job_description'] as String?)?.trim() ?? '';

                      // ✅ nome do outro lado (no cliente -> provider)
                      final displayName =
                          (c['display_name'] as String?)?.trim() ??
                              'Profissional';

                      // ✅ avatar do outro lado
                      final avatarUrl =
                          (c['display_avatar_url'] as String?)?.trim();

                      // última msg / horário
                      final lastMsg =
                          (c['last_message_content'] as String?)?.trim() ?? '';
                      final timeLabel =
                          _formatTime(c['last_message_created_at']?.toString());

                      final fallbackLetter = _firstLetter(displayName);

                      return Material(
                        color: index % 2 == 0
                            ? const Color(0xFFF7F7F7)
                            : Colors.white,
                        child: InkWell(
                          onTap: () {
                            final user = _supabase.auth.currentUser;
                            if (user == null) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  conversationId: conversationId,
                                  // fallback (header oficial vem da view no ChatPage)
                                  jobTitle: pedidoLabel,
                                  otherUserName: displayName,
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
                                _avatar(avatarUrl, fallbackLetter),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: roxo,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pedidoLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (jobDescription.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          jobDescription,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      if (lastMsg.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45,
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
                                    const Icon(Icons.chevron_right,
                                        color: Colors.grey),
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
