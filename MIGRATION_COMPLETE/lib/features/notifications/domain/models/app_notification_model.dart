import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification_model.freezed.dart';
part 'app_notification_model.g.dart';

/// Model de Notificação
@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String userId,
    required String title,
    required String body,
    NotificationType? type,
    String? imageUrl,
    String? actionUrl,
    Map<String, dynamic>? data,
    @Default(false) bool isRead,
    DateTime? readAt,
    required DateTime createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] != null
          ? NotificationType.fromString(map['type'] as String)
          : null,
      imageUrl: map['image_url'] as String?,
      actionUrl: map['action_url'] as String?,
      data: map['data'] as Map<String, dynamic>?,
      isRead: map['is_read'] as bool? ?? false,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Tipo de notificação
enum NotificationType {
  newJob,
  newMessage,
  jobAccepted,
  jobCompleted,
  jobCancelled,
  payment,
  review,
  system;

  String toJson() => name;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'new_job':
        return NotificationType.newJob;
      case 'new_message':
        return NotificationType.newMessage;
      case 'job_accepted':
        return NotificationType.jobAccepted;
      case 'job_completed':
        return NotificationType.jobCompleted;
      case 'job_cancelled':
        return NotificationType.jobCancelled;
      case 'payment':
        return NotificationType.payment;
      case 'review':
        return NotificationType.review;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.newJob:
        return 'Novo Serviço';
      case NotificationType.newMessage:
        return 'Nova Mensagem';
      case NotificationType.jobAccepted:
        return 'Serviço Aceito';
      case NotificationType.jobCompleted:
        return 'Serviço Concluído';
      case NotificationType.jobCancelled:
        return 'Serviço Cancelado';
      case NotificationType.payment:
        return 'Pagamento';
      case NotificationType.review:
        return 'Avaliação';
      case NotificationType.system:
        return 'Sistema';
    }
  }
}

/// Extension para helpers
extension AppNotificationX on AppNotification {
  /// Horário relativo
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) return 'Agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}sem atrás';
    
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Ícone baseado no tipo
  String get icon {
    switch (type) {
      case NotificationType.newJob:
        return '💼';
      case NotificationType.newMessage:
        return '💬';
      case NotificationType.jobAccepted:
        return '✅';
      case NotificationType.jobCompleted:
        return '🎉';
      case NotificationType.jobCancelled:
        return '❌';
      case NotificationType.payment:
        return '💰';
      case NotificationType.review:
        return '⭐';
      case NotificationType.system:
      default:
        return '🔔';
    }
  }
}
