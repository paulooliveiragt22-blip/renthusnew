import 'package:flutter/material.dart';
import 'package:renthus/app_navigator.dart';
import 'package:renthus/screens/chat_page.dart';
import 'package:renthus/screens/job_details_page.dart';

class PushNavigationHandler {
  static void handle(
    Map<String, dynamic> data,
    String currentUserRole,
    String currentUserId,
  ) {
    final nav = AppNavigator.navigatorKey.currentState;
    if (nav == null) return;

    final type = data['type'] as String?;
    final jobId = data['job_id'] as String?;
    final conversationId = data['conversation_id'] as String?;
    final otherUserName = data['other_user_name'] as String? ?? '';
    final jobTitle = data['job_title'] as String? ?? 'Chat do serviço';

    switch (type) {
      case 'chat_message':
        if (conversationId != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: conversationId,
                currentUserRole: currentUserRole,
                currentUserId: currentUserId, // <<<<<< AQUI
                otherUserName: otherUserName,
                jobTitle: jobTitle,
              ),
            ),
          );
        } else if (jobId != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => JobDetailsPage(jobId: jobId),
            ),
          );
        }
        break;

      case 'job_status':
      case 'new_candidate':
        if (jobId != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => JobDetailsPage(jobId: jobId),
            ),
          );
        }
        break;

      default:
        if (jobId != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => JobDetailsPage(jobId: jobId),
            ),
          );
        }
    }
  }
}
