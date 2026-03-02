import 'package:flutter/foundation.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/user_role_holder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNavigationHandler {
  static void handle(
    Map<String, dynamic> data,
    String currentUserRole,
    String currentUserId,
  ) {
    final type = data['type'] as String?;
    final jobId = data['job_id'] as String?;
    final conversationId = data['conversation_id'] as String?;
    final otherUserName = data['other_user_name'] as String? ?? '';
    final jobTitle = data['job_title'] as String? ?? 'Chat do serviço';
    final disputeId = data['dispute_id'] as String?;

    final isClient = currentUserRole.toLowerCase() == 'client';

    debugPrint('PushNavigationHandler: type=$type, jobId=$jobId, '
        'conversationId=$conversationId, isClient=$isClient');

    switch (type) {
      // === CHAT ===
      case 'chat_message':
      case 'new_message':
        if (conversationId != null) {
          goRouter.push(
            AppRoutes.chat,
            extra: {
              'conversationId': conversationId,
              'currentUserRole': currentUserRole,
              'currentUserId': currentUserId,
              'otherUserName': otherUserName,
              'jobTitle': jobTitle,
            },
          );
        } else if (jobId != null) {
          _navigateToJob(jobId, isClient);
        }
        break;

      // === JOB ===
      case 'new_candidate':
      case 'new_quote':
      case 'quote_accepted':
      case 'quote_rejected':
      case 'job_status':
      case 'job_started':
      case 'new_job':
      case 'job_accepted':
      case 'job_completed':
      case 'job_cancelled':
        if (jobId != null) {
          _navigateToJob(jobId, isClient);
        } else {
          _goToJobsTab(isClient);
        }
        break;

      // === PAGAMENTO ===
      case 'payment_received':
      case 'payment_confirmed':
        if (jobId != null) {
          _navigateToJob(jobId, isClient);
        }
        break;

      case 'payment_failed':
        if (jobId != null && isClient) {
          goRouter.push(AppRoutes.clientPayment, extra: {'jobId': jobId});
        } else if (jobId != null) {
          _navigateToJob(jobId, isClient);
        }
        break;

      // === AVALIAÇÃO ===
      case 'review_received':
      case 'review':
        if (jobId != null) {
          _navigateToJob(jobId, isClient);
        }
        break;

      // === DISPUTA ===
      case 'dispute_opened':
      case 'dispute_resolved':
        if (isClient && jobId != null) {
          goRouter.push(AppRoutes.clientDispute, extra: {'jobId': jobId});
        } else if (!isClient && (disputeId ?? jobId) != null) {
          goRouter.push(
              '${AppRoutes.providerDispute}/${disputeId ?? jobId}');
        }
        break;

      // === VERIFICAÇÃO ===
      case 'verification_approved':
        if (!isClient) {
          goRouter.go(AppRoutes.providerHome);
        }
        break;

      case 'verification_rejected':
        if (!isClient) {
          goRouter.push(AppRoutes.providerVerification);
        }
        break;

      // === FALLBACK ===
      default:
        if (jobId != null) {
          _navigateToJob(jobId, isClient);
        } else {
          goRouter.push(AppRoutes.notifications,
              extra: {'currentUserRole': currentUserRole});
        }
    }

    // Mark as read if notification_id is present
    final notificationId = data['notification_id'] as String?;
    if (notificationId != null) {
      _markAsRead(notificationId);
    }
  }

  /// Navigate from push payload using UserRoleHolder
  static void handleFromPush(Map<String, dynamic> data) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    handle(data, UserRoleHolder.currentRole, user.id);
  }

  static void _navigateToJob(String jobId, bool isClient) {
    if (isClient) {
      goRouter.push('${AppRoutes.clientJobDetails}/$jobId');
    } else {
      goRouter.push('${AppRoutes.jobDetails}/$jobId');
    }
  }

  static void _goToJobsTab(bool isClient) {
    if (isClient) {
      goRouter.go(AppRoutes.clientHome);
    } else {
      goRouter.go(AppRoutes.providerHome);
    }
  }

  static Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({
            'read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Erro ao marcar notificação como lida: $e');
    }
  }
}
