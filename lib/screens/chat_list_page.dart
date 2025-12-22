// lib/screens/chat_list_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/chat_repository.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  /// true = cliente, false = prestador
  final bool isClient;

  const ChatListPage({
    super.key,
    required this.isClient,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late final SupabaseClient _client;
  late final ChatRepository _chatRepository;

  bool _loading = true;
  String? _authUserId; // auth.users.id
  String? _partyId; // clients.id ou providers.id
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _chatRepository = ChatRepository.withClient(_client);
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _conversations = [];
    });

    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    _authUserId = user.id;

    try {
      // Descobre o "party id" correto (clients.id ou providers.id)
      String? partyId;

      if (widget.isClient) {
        // CLIENTE -> usa clients.id
        final row = await _client
            .from('clients')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        partyId = row?['id']?.toString();
      } else {
        // PRESTADOR -> usa providers.id
        final row = await _client
            .from('providers')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        partyId = row?['id']?.toString();
      }

      if (partyId == null) {
        setState(() {
          _partyId = null;
          _conversations = [];
          _loading = false;
        });
        return;
      }

      _partyId = partyId;

      // Busca conversas para esse partyId (cliente ou prestador)
      final rows = await _chatRepository.fetchConversationsForUser(
        partyId: partyId,
        isClient: widget.isClient,
      );

      setState(() {
        _conversations = rows;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar conversas: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _conversations = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar conversas: $e')),
      );
    }
  }

  Future<void> _reload() async {
    await _loadConversations();
  }

  void _openConversation(Map<String, dynamic> row) {
    if (_authUserId == null) return;

    final conversationId = row['id']?.toString();
    if (conversationId == null) return;

    final jobTitle = (row['title'] as String?)?.trim().isNotEmpty == true
        ? row['title'] as String
        : 'Chat do serviço';

    // Tenta descobrir um nome amigável do outro lado
    final otherUserName = widget.isClient
        ? (row['provider_name'] as String?) ??
            row['other_name']?.toString() ??
            'Prestador'
        : (row['client_name'] as String?) ??
            row['other_name']?.toString() ??
            'Cliente';

    // Caso o seu schema tenha alguma flag, tentamos usar;
    // senão, o chat fica sempre liberado.
    final bool isLocked = (row['is_closed'] as bool?) ??
        (row['is_chat_locked'] as bool?) ??
        false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          jobTitle: jobTitle,
          otherUserName: otherUserName,
          currentUserId: _authUserId!,
          currentUserRole: widget.isClient ? 'client' : 'provider',
          isChatLocked: isLocked,
        ),
      ),
    );
  }

  String _formatLastMessageTime(Map<String, dynamic> row) {
    final createdStr = row['last_message_created_at']?.toString() ??
        row['created_at']?.toString();
    if (createdStr == null) return '';
    final dt = DateTime.tryParse(createdStr)?.toLocal();
    if (dt == null) return '';

    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _extractLastMessagePreview(Map<String, dynamic> row) {
    final msg = row['last_message_content'] ??
        row['last_message'] ??
        row['last_message_text'] ??
        row['last_message_preview'];
    if (msg == null) return '';
    final s = msg.toString().trim();
    if (s.isEmpty) return '';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isClient ? 'Meus chats' : 'Chats com clientes';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF3B246B),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _partyId == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Não encontramos seu cadastro para exibir conversas.\n'
                        'Finalize seu cadastro e tente novamente.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _conversations.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'Você ainda não tem conversas.\n'
                            'Quando um serviço for iniciado, o chat aparecerá aqui.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final row = _conversations[index];

                          final title =
                              (row['title'] as String?)?.trim().isNotEmpty ==
                                      true
                                  ? row['title'] as String
                                  : 'Chat do serviço';

                          final lastMessage = _extractLastMessagePreview(row);
                          final timeLabel = _formatLastMessageTime(row);

                          final unreadCount =
                              (row['unread_count'] as int?) ?? 0;
                          final hasUnread = unreadCount > 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              onTap: () => _openConversation(row),
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF3B246B).withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  color:
                                      const Color(0xFF3B246B).withOpacity(0.8),
                                ),
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: lastMessage.isEmpty
                                  ? null
                                  : Text(
                                      lastMessage,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                              trailing: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (timeLabel.isNotEmpty)
                                    Text(
                                      timeLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  if (hasUnread)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        unreadCount > 9
                                            ? '9+'
                                            : unreadCount.toString(),
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
                        },
                      ),
      ),
    );
  }
}
