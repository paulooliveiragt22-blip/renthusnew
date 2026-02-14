import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/notifications/data/providers/notification_providers.dart';
import 'package:renthus/features/notifications/domain/models/app_notification_model.dart'
    as models;

/// Tela de notificações migrada para Riverpod.
///
/// currentUserRole: 'provider' ou 'client' — define textos e navegação.
class NotificationsPage extends ConsumerWidget {

  const NotificationsPage({
    super.key,
    this.currentUserRole = 'provider',
  });
  final String currentUserRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final notificationsAsync = ref.watch(notificationsStreamProvider(userId));

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
          _MarkAllReadButton(
            currentUserRole: currentUserRole,
            userId: userId,
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar notificações',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Você ainda não tem notificações.\n'
                  'Quando algo importante acontecer, aparecerá aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsStreamProvider(userId));
            },
            child: _NotificationsList(
              items: items,
              currentUserRole: currentUserRole,
              userId: userId,
            ),
          );
        },
      ),
    );
  }
}

class _MarkAllReadButton extends ConsumerWidget {

  const _MarkAllReadButton({
    required this.currentUserRole,
    required this.userId,
  });
  final String currentUserRole;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync =
        ref.watch(notificationsStreamProvider(userId));

    return notificationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final hasUnread = items.any((n) => !n.isRead);
        if (!hasUnread) return const SizedBox.shrink();

        return TextButton(
          onPressed: () async {
            await ref
                .read(notificationActionsProvider.notifier)
                .markAllAsRead(userId);
          },
          child: const Text(
            'Marcar todas como lidas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}

class _NotificationsList extends ConsumerWidget {

  const _NotificationsList({
    required this.items,
    required this.currentUserRole,
    required this.userId,
  });
  final List<models.AppNotification> items;
  final String currentUserRole;
  final String userId;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final notif = items[index];
        final dateText = _dateFormat.format(notif.createdAt.toLocal());
        final title = _resolveTitle(notif, currentUserRole);
        final body = _resolveBody(notif, currentUserRole);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _handleTap(context, ref, notif, currentUserRole, userId),
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
                        color: notif.isRead
                            ? Colors.transparent
                            : const Color(0xFF3B246B),
                        shape: BoxShape.circle,
                        border: notif.isRead
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  notif.isRead ? FontWeight.w500 : FontWeight.w700,
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
    );
  }
}

String _resolveTitle(models.AppNotification n, String currentUserRole) {
  final data = n.data ?? <String, dynamic>{};
  final type = (data['type'] as String?) ?? '';

  if (type == 'chat_message') {
    return currentUserRole == 'provider'
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

String _resolveBody(models.AppNotification n, String currentUserRole) {
  if (n.body.isNotEmpty) return n.body;

  final data = n.data ?? <String, dynamic>{};
  final type = (data['type'] as String?) ?? '';
  final jobTitle = (data['job_title'] as String?) ?? 'seu pedido';

  if (type == 'chat_message') {
    return currentUserRole == 'provider'
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

Future<void> _handleTap(
  BuildContext context,
  WidgetRef ref,
  models.AppNotification notif,
  String currentUserRole,
  String userId,
) async {
  if (!notif.isRead) {
    await ref.read(notificationActionsProvider.notifier).markAsRead(notif.id, userId);
  }

  final data = notif.data ?? <String, dynamic>{};
  final type = (data['type'] as String?) ?? '';

  if (type == 'job_status' || type == 'new_candidate') {
    final String jobId = data['job_id']?.toString() ?? '';
    if (jobId.isNotEmpty && context.mounted) {
      if (currentUserRole == 'client') {
        await context.pushClientJobDetails(jobId);
      } else {
        await context.pushJobDetails(jobId);
      }
    }
    return;
  }

  if (type == 'chat_message') {
    final String conversationId = data['conversation_id']?.toString() ?? '';
    final String jobId = data['job_id']?.toString() ?? '';
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final otherUserName =
        currentUserRole == 'provider' ? 'Cliente' : 'Prestador';

    if (conversationId.isNotEmpty) {
      String jobTitle = 'Chat do serviço';
      try {
        final conv = await supabase
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

      if (context.mounted) {
        await context.pushChat({
          'conversationId': conversationId,
          'jobTitle': jobTitle,
          'otherUserName': otherUserName,
          'currentUserId': user.id,
          'currentUserRole': currentUserRole,
          'isChatLocked': false,
        });
      }
      return;
    }

    if (jobId.isNotEmpty && context.mounted) {
      if (currentUserRole == 'client') {
        await context.pushClientJobDetails(jobId);
      } else {
        await context.pushJobDetails(jobId);
      }
    }
    return;
  }

  final String fallbackJobId = data['job_id']?.toString() ?? '';
  if (fallbackJobId.isNotEmpty && context.mounted) {
    if (currentUserRole == 'client') {
      await context.pushClientJobDetails(fallbackJobId);
    } else {
      await context.pushJobDetails(fallbackJobId);
    }
  }
}
