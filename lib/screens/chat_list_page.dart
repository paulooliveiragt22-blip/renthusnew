import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool _loading = true;
  String? _authUserId; // auth.users.id
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _loadConversations();
  }

  String get _viewName =>
      widget.isClient ? 'v_client_chats' : 'v_provider_chats';

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _conversations = [];
    });

    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    _authUserId = user.id;

    try {
      final rows = await _client.from(_viewName).select('''
            conversation_id,
            job_id,
            client_id,
            provider_id,
            job_code,
            job_description,
            provider_full_name,
            clients_full_name,
            provider_avatar_url,
            client_avatar_url,
            display_name,
            display_avatar_url,
            last_message_content,
            last_message_created_at,
            last_sender_id,
            last_sender_role
          ''').order('last_message_created_at', ascending: false);

      final list = (rows as List).cast<Map<String, dynamic>>();

      setState(() {
        _conversations = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar conversas (view $_viewName): $e');
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

  Future<void> _reload() async => _loadConversations();

  void _openConversation(Map<String, dynamic> row) {
    if (_authUserId == null) return;

    final conversationId = row['conversation_id']?.toString();
    if (conversationId == null) return;

    final jobCode = (row['job_code'] as String?)?.trim();
    final jobTitle = (jobCode != null && jobCode.isNotEmpty)
        ? 'Pedido #$jobCode'
        : 'Chat do serviço';

    final otherUserName =
        (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? row['display_name'] as String
            : (widget.isClient ? 'Prestador' : 'Cliente');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          jobTitle:
              jobTitle, // você pode usar isso no AppBar (ou trocar depois pelo header view)
          otherUserName: otherUserName,
          currentUserId: _authUserId!,
          currentUserRole: widget.isClient ? 'client' : 'provider',
          isChatLocked: false,
        ),
      ),
    );
  }

  String _formatLastMessageTime(Map<String, dynamic> row) {
    final createdStr = row['last_message_created_at']?.toString();
    if (createdStr == null || createdStr.isEmpty) return '';
    final dt = DateTime.tryParse(createdStr)?.toLocal();
    if (dt == null) return '';

    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _extractLastMessagePreview(Map<String, dynamic> row) {
    final msg = row['last_message_content'];
    if (msg == null) return '';
    final s = msg.toString().trim();
    if (s.isEmpty) return '';
    return s;
  }

  Widget _buildAvatar(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) {
      return CircleAvatar(
        backgroundColor: const Color(0xFF3B246B).withOpacity(0.1),
        child: Icon(
          Icons.person,
          color: const Color(0xFF3B246B).withOpacity(0.8),
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: const Color(0xFF3B246B).withOpacity(0.08),
      backgroundImage: NetworkImage(u),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.isClient ? 'Chats' : 'Chats';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: const Color(0xFF3B246B),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final row = _conversations[index];

                      final jobCode = (row['job_code'] as String?)?.trim();
                      final title = (jobCode != null && jobCode.isNotEmpty)
                          ? 'Pedido #$jobCode'
                          : 'Pedido';

                      final description =
                          (row['job_description'] as String?)?.trim() ?? '';

                      final otherName =
                          (row['display_name'] as String?)?.trim() ?? '';

                      final avatarUrl =
                          (row['display_avatar_url'] as String?)?.trim();

                      final timeLabel = _formatLastMessageTime(row);

                      // opcional: preview da última msg (se você quiser mostrar no lugar da descrição, troque)
                      final lastMessage = _extractLastMessagePreview(row);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          onTap: () => _openConversation(row),
                          leading: _buildAvatar(avatarUrl),
                          title: Text(
                            otherName.isNotEmpty ? otherName : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                title, // "Pedido #RTH-000067"
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description, // jobs.description
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ] else if (lastMessage.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  lastMessage,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ],
                          ),
                          trailing: timeLabel.isEmpty
                              ? null
                              : Text(
                                  timeLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
