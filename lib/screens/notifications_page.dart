import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'job_details_page.dart';
import 'client_job_details_page.dart'; // 👈 novo import
import 'chat_page.dart';

/// currentUserRole:
///   - 'provider'  -> textos / navegação de prestador
///   - 'client'    -> textos / navegação de cliente
class NotificationsPage extends StatefulWidget {
  final String currentUserRole;

  const NotificationsPage({
    super.key,
    this.currentUserRole = 'provider',
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = NotificationRepository();
  final _supabase = Supabase.instance.client;

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isLoading = true;
  List<AppNotification> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.fetchLatest(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar notificações: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar notificações: $e')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map((n) => n.copyWith(read: true)).toList();
      });
    } catch (e) {
      debugPrint('Erro ao marcar todas como lidas: $e');
    }
  }

  /// Retorna a tela correta de detalhes, de acordo com o papel atual
  Widget _buildJobDetailsPage(String jobId) {
    if (widget.currentUserRole == 'client') {
      return ClientJobDetailsPage(jobId: jobId);
    }
    return JobDetailsPage(jobId: jobId);
  }

  Future<void> _handleTap(AppNotification notif) async {
    // marca como lida
    if (!notif.read) {
      try {
        await _repo.markAsRead(notif.id);
        if (mounted) {
          setState(() {
            _items = _items
                .map((n) => n.id == notif.id ? n.copyWith(read: true) : n)
                .toList();
          });
        }
      } catch (e) {
        debugPrint('Erro ao marcar notificação como lida: $e');
      }
    }

    final data = notif.data ?? <String, dynamic>{};
    final type = (data['type'] as String?) ?? '';

    // ---------- STATUS DO SERVIÇO / NOVO CANDIDATO ----------
    if (type == 'job_status' || type == 'new_candidate') {
      final String jobId = data['job_id']?.toString() ?? '';
      if (jobId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _buildJobDetailsPage(jobId),
          ),
        );
      }
      return;
    }

    // ---------- MENSAGEM DE CHAT ----------
    if (type == 'chat_message') {
      final String conversationId = data['conversation_id']?.toString() ?? '';
      final String jobId = data['job_id']?.toString() ?? '';
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final otherUserName =
          widget.currentUserRole == 'provider' ? 'Cliente' : 'Prestador';

      if (conversationId.isNotEmpty) {
        String jobTitle = 'Chat do serviço';
        try {
          final conv = await _supabase
              .from('conversations')
              .select('title')
              .eq('id', conversationId)
              .maybeSingle();

          final rawTitle = conv?['title'] as String?;
          if (rawTitle != null && rawTitle.trim().isNotEmpty) {
            jobTitle = rawTitle;
          }
        } catch (e) {
          debugPrint('Erro ao buscar conversa: $e');
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conversationId,
              jobTitle: jobTitle,
              otherUserName: otherUserName,
              currentUserId: user.id,
              currentUserRole: widget.currentUserRole,
            ),
          ),
        );
        return;
      }

      // fallback: se não tiver conversation_id, pelo menos abre o job
      if (jobId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _buildJobDetailsPage(jobId),
          ),
        );
      }
      return;
    }

    // ---------- OUTROS TIPOS (FALLBACK) ----------
    // Se tiver job_id no data, abrimos a tela de detalhes correta
    final String fallbackJobId = data['job_id']?.toString() ?? '';
    if (fallbackJobId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _buildJobDetailsPage(fallbackJobId),
        ),
      );
    }
  }

  String _resolveTitle(AppNotification n) {
    final data = n.data ?? <String, dynamic>{};
    final type = (data['type'] as String?) ?? '';

    if (type == 'chat_message') {
      return widget.currentUserRole == 'provider'
          ? 'Nova mensagem do cliente'
          : 'Nova mensagem do prestador';
    }

    if (type == 'job_status') {
      final status = (data['status'] as String?) ?? '';
      switch (status) {
        case 'accepted':
          return 'Pedido aprovado';
        case 'on_the_way':
          return 'Prestador a caminho';
        case 'in_progress':
          return 'Serviço em andamento';
        case 'completed':
          return 'Serviço finalizado';
        case 'cancelled':
        case 'cancelled_by_client':
        case 'cancelled_by_provider':
          return 'Pedido cancelado';
        default:
          return 'Atualização do pedido';
      }
    }

    if (type == 'new_candidate') {
      return 'Novo prestador interessado';
    }

    if (n.title.isNotEmpty) return n.title;
    return 'Notificação';
  }

  String _resolveBody(AppNotification n) {
    if (n.body.isNotEmpty) return n.body;

    final data = n.data ?? <String, dynamic>{};
    final type = (data['type'] as String?) ?? '';

    final jobTitle = (data['job_title'] as String?) ?? 'seu pedido';

    if (type == 'chat_message') {
      return widget.currentUserRole == 'provider'
          ? 'Você recebeu uma nova mensagem do cliente em $jobTitle.'
          : 'Você recebeu uma nova mensagem do prestador em $jobTitle.';
    }

    if (type == 'job_status') {
      final status = (data['status'] as String?) ?? '';
      switch (status) {
        case 'accepted':
          return 'O pedido $jobTitle foi aprovado.';
        case 'on_the_way':
          return 'O prestador está a caminho para o serviço $jobTitle.';
        case 'in_progress':
          return 'O serviço $jobTitle está em andamento.';
        case 'completed':
          return 'O serviço $jobTitle foi marcado como concluído.';
        case 'cancelled':
        case 'cancelled_by_client':
          return 'O pedido $jobTitle foi cancelado pelo cliente.';
        case 'cancelled_by_provider':
          return 'Você cancelou o pedido $jobTitle.';
        default:
          return 'O status de $jobTitle foi atualizado.';
      }
    }

    if (type == 'new_candidate') {
      return 'Um prestador se candidatou ao serviço $jobTitle.';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notificações',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Marcar todas como lidas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Você ainda não tem notificações.\n'
                        'Quando algo importante acontecer, aparecerá aqui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final notif = _items[index];
                      final createdAt = notif.createdAt;
                      final dateText = createdAt != null
                          ? _dateFormat.format(createdAt.toLocal())
                          : '';

                      final title = _resolveTitle(notif);
                      final body = _resolveBody(notif);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _handleTap(notif),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: notif.read
                                          ? Colors.transparent
                                          : const Color(0xFF3B246B),
                                      shape: BoxShape.circle,
                                      border: notif.read
                                          ? Border.all(
                                              color: Colors.grey.shade400,
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: notif.read
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: const Color(0xFF3B246B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (body.isNotEmpty) ...[
                                          Text(
                                            body,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        Text(
                                          dateText,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
