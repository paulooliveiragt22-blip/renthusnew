import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'job_details_page.dart';
import 'client_job_details_page.dart';
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

  static const roxo = Color(0xFF3B246B);

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
    final type = _resolveType(notif);

    // ---------- STATUS DO SERVIÇO / NOVO CANDIDATO ----------
    if (type == 'job_status' || type == 'new_candidate') {
      final String jobId = data['job_id']?.toString() ?? '';
      if (jobId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _buildJobDetailsPage(jobId)),
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
          MaterialPageRoute(builder: (_) => _buildJobDetailsPage(jobId)),
        );
      }
      return;
    }

    // ---------- OUTROS TIPOS (FALLBACK) ----------
    final String fallbackJobId = data['job_id']?.toString() ?? '';
    if (fallbackJobId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _buildJobDetailsPage(fallbackJobId)),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HUMANIZAÇÃO (corrige o "on_the_way", "in_progress" etc)
  // ---------------------------------------------------------------------------

  /// Se o backend não enviar data.type, a gente tenta inferir pelo texto
  String _resolveType(AppNotification n) {
    final data = n.data ?? <String, dynamic>{};
    final explicit = (data['type'] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final title = (n.title).toLowerCase();
    final body = (n.body).toLowerCase();

    // padrão do print: "Status do seu serviço foi atualizado"
    if (title.contains('status do seu serviço') ||
        body.contains('o status do seu serviço') ||
        body.contains('agora é:')) {
      return 'job_status';
    }

    if (title.contains('mensagem') ||
        body.contains('você recebeu uma mensagem') ||
        body.contains('nova mensagem')) {
      return 'chat_message';
    }

    if (title.contains('proposta') || body.contains('proposta')) {
      return 'new_candidate';
    }

    return '';
  }

  /// tenta pegar o status do data['status'] ou de dentro do body ("agora é: on_the_way")
  String _resolveStatus(AppNotification n) {
    final data = n.data ?? <String, dynamic>{};
    final fromData = (data['status'] as String?)?.trim();
    if (fromData != null && fromData.isNotEmpty) return fromData;

    final body = n.body;
    final idx = body.indexOf('agora é:');
    if (idx >= 0) {
      final raw = body.substring(idx + 'agora é:'.length).trim();
      // pega só o primeiro token (caso venha com mais texto)
      final token = raw.split(RegExp(r'\s+')).first.trim();
      if (token.isNotEmpty) return token;
    }

    return '';
  }

  String _statusHuman(String status) {
    switch (status) {
      case 'accepted':
        return 'aceito';
      case 'on_the_way':
        return 'a caminho';
      case 'in_progress':
        return 'em andamento';
      case 'completed':
        return 'finalizado';
      case 'cancelled':
      case 'cancelled_by_client':
      case 'cancelled_by_provider':
        return 'cancelado';
      default:
        return 'atualizado';
    }
  }

  String _resolveTitle(AppNotification n) {
    final type = _resolveType(n);
    final data = n.data ?? <String, dynamic>{};

    if (type == 'chat_message') {
      return widget.currentUserRole == 'provider'
          ? 'Nova mensagem do cliente'
          : 'Nova mensagem do prestador';
    }

    if (type == 'job_status') {
      final status = _resolveStatus(n);
      switch (status) {
        case 'accepted':
          return 'Pedido aceito';
        case 'on_the_way':
          return 'Profissional a caminho';
        case 'in_progress':
          return 'Serviço iniciado';
        case 'completed':
          return 'Serviço finalizado';
        case 'cancelled':
        case 'cancelled_by_client':
        case 'cancelled_by_provider':
          return 'Pedido cancelado';
        default:
          return 'Atualização do serviço';
      }
    }

    if (type == 'new_candidate') {
      return 'Nova proposta recebida';
    }

    // fallback: se veio do banco já bonitinho, usa
    if (n.title.trim().isNotEmpty) return n.title.trim();
    return 'Notificação';
  }

  String _resolveBody(AppNotification n) {
    final type = _resolveType(n);
    final data = n.data ?? <String, dynamic>{};

    final jobCode = (data['job_code'] as String?) ?? '';
    final jobLabel = jobCode.isNotEmpty ? ' ($jobCode)' : '';

    final jobTitleRaw = (data['job_title'] as String?)?.trim();
    final jobTitle = (jobTitleRaw != null && jobTitleRaw.isNotEmpty)
        ? jobTitleRaw
        : 'seu pedido';

    // ✅ CHAT: se existir body e estiver legal, pode usar, senão humaniza
    if (type == 'chat_message') {
      if (n.body.trim().isNotEmpty) return n.body.trim();
      return widget.currentUserRole == 'provider'
          ? 'Você recebeu uma mensagem do cliente em "$jobTitle".$jobLabel'
          : 'Você recebeu uma mensagem do prestador em "$jobTitle".$jobLabel';
    }

    // ✅ STATUS: SEMPRE humaniza (mesmo que n.body venha preenchido cru)
    if (type == 'job_status') {
      final status = _resolveStatus(n);
      final human = _statusHuman(status);

      // extras (se você já estiver salvando isso no data)
      final int? eta = (data['eta_minutes'] is num)
          ? (data['eta_minutes'] as num).toInt()
          : null;

      final startedAgo = (data['started_ago'] as String?)?.trim(); // opcional
      final completedAt =
          (data['completed_time'] as String?)?.trim(); // opcional

      if (status == 'accepted') {
        return 'Tudo certo! O profissional aceitou o serviço "$jobTitle".$jobLabel';
      }

      if (status == 'on_the_way') {
        if (eta != null && eta > 0) {
          return 'O profissional está a caminho. Chegada estimada: ${_fmtEta(eta)}.$jobLabel';
        }
        return 'O profissional está a caminho do seu endereço.$jobLabel';
      }

      if (status == 'in_progress') {
        if (startedAgo != null && startedAgo.isNotEmpty) {
          return 'O serviço começou $startedAgo.$jobLabel';
        }
        return 'O serviço "$jobTitle" começou e já está em andamento.$jobLabel';
      }

      if (status == 'completed') {
        if (completedAt != null && completedAt.isNotEmpty) {
          return 'Serviço finalizado às $completedAt. Se puder, deixe uma avaliação 🙂$jobLabel';
        }
        return 'Serviço finalizado. Se puder, deixe uma avaliação 🙂$jobLabel';
      }

      if (status == 'cancelled' || status == 'cancelled_by_client') {
        return 'Este pedido foi cancelado.$jobLabel';
      }

      if (status == 'cancelled_by_provider') {
        return 'O profissional cancelou este pedido.$jobLabel';
      }

      return 'O status do serviço foi $human.$jobLabel';
    }

    if (type == 'new_candidate') {
      if (n.body.trim().isNotEmpty) return n.body.trim();
      return 'Um profissional enviou uma proposta para "$jobTitle".$jobLabel';
    }

    // fallback geral: se tiver body, mostra
    if (n.body.trim().isNotEmpty) return n.body.trim();
    return '';
  }

  String _fmtEta(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${minutes} min';
    if (m == 0) return '${h} h';
    return '${h} h ${m} min';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: roxo,
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
                                          : roxo,
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
                                            color: roxo,
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
