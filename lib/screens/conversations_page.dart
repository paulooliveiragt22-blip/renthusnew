import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_page.dart';
import '../repositories/chat_repository.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _chatRepo = ChatRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Faça login novamente.';
        });
        return;
      }

      final rows = await _chatRepo.fetchConversationsForUser(user.id);
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar conversas: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: AppBar(title: Text('Conversas')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversas')),
        body: Center(child: Text(_error!)),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversas')),
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

    final userId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversas'),
        backgroundColor: const Color(0xFF3B246B),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final c = _items[index];
            final conversationId = c['id'].toString();
            final title = (c['title'] as String?) ?? 'Chat';
            final lastMsg =
                (c['last_message_content'] as String?) ?? 'Sem mensagens ainda';
            final lastAt = c['last_message_created_at']?.toString();

            // descobrindo se o user é cliente ou prestador nessa conversa
            final isClient = c['client_id'] == userId;
            final otherName = isClient
                ? 'Prestador'
                : 'Cliente'; // pode melhorar futuramente

            String subtitle = lastMsg;
            if (lastMsg.length > 60) {
              subtitle = '${lastMsg.substring(0, 57)}...';
            }

            return ListTile(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: lastAt != null
                  ? Text(
                      lastAt.split('T').first, // simplão só para começo
                      style: const TextStyle(fontSize: 11),
                    )
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      conversationId: conversationId,
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
  }
}
