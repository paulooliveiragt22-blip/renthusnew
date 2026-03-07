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
    final data = map['data'] as Map<String, dynamic>?;
    // type column, fallback to data->type
    final typeStr = (map['type'] as String?) ?? (data?['type'] as String?);

    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: typeStr != null ? NotificationType.fromString(typeStr) : null,
      imageUrl: map['image_url'] as String?,
      actionUrl: map['action_url'] as String?,
      data: data,
      isRead: map['read'] as bool? ?? false,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Categorias para badges nas tabs
enum NotificationCategory {
  jobs,
  chat,
  profile,
  general,
}

/// Tipo de notificação
enum NotificationType {
  // Jobs
  newJob,
  newCandidate,
  newQuote,
  quoteAccepted,
  quoteRejected,
  jobStarted,
  jobAccepted,
  jobCompleted,
  jobCancelled,
  jobStatus,

  // Pagamento
  paymentReceived,
  paymentConfirmed,
  paymentFailed,
  payment,

  // Chat
  chatMessage,
  newMessage,

  // Avaliação
  reviewReceived,
  review,

  // Disputa
  disputeOpened,
  disputeResolved,

  // Verificação
  verificationApproved,
  verificationRejected,

  // Geral
  general,
  system;

  String toJson() => name;

  /// String que vai no banco (coluna `type`)
  String get value {
    switch (this) {
      case NotificationType.newJob: return 'new_job';
      case NotificationType.newCandidate: return 'new_candidate';
      case NotificationType.newQuote: return 'new_quote';
      case NotificationType.quoteAccepted: return 'quote_accepted';
      case NotificationType.quoteRejected: return 'quote_rejected';
      case NotificationType.jobStarted: return 'job_started';
      case NotificationType.jobAccepted: return 'job_accepted';
      case NotificationType.jobCompleted: return 'job_completed';
      case NotificationType.jobCancelled: return 'job_cancelled';
      case NotificationType.jobStatus: return 'job_status';
      case NotificationType.paymentReceived: return 'payment_received';
      case NotificationType.paymentConfirmed: return 'payment_confirmed';
      case NotificationType.paymentFailed: return 'payment_failed';
      case NotificationType.payment: return 'payment';
      case NotificationType.chatMessage: return 'chat_message';
      case NotificationType.newMessage: return 'new_message';
      case NotificationType.reviewReceived: return 'review_received';
      case NotificationType.review: return 'review';
      case NotificationType.disputeOpened: return 'dispute_opened';
      case NotificationType.disputeResolved: return 'dispute_resolved';
      case NotificationType.verificationApproved: return 'verification_approved';
      case NotificationType.verificationRejected: return 'verification_rejected';
      case NotificationType.general: return 'general';
      case NotificationType.system: return 'system';
    }
  }

  static NotificationType fromString(String? value) {
    switch (value) {
      case 'new_job': return NotificationType.newJob;
      case 'new_candidate': return NotificationType.newCandidate;
      case 'new_quote': return NotificationType.newQuote;
      case 'quote_accepted': return NotificationType.quoteAccepted;
      case 'quote_rejected': return NotificationType.quoteRejected;
      case 'job_started': return NotificationType.jobStarted;
      case 'job_accepted': return NotificationType.jobAccepted;
      case 'job_completed': return NotificationType.jobCompleted;
      case 'job_cancelled': return NotificationType.jobCancelled;
      case 'job_status': return NotificationType.jobStatus;
      case 'payment_received': return NotificationType.paymentReceived;
      case 'payment_confirmed': return NotificationType.paymentConfirmed;
      case 'payment_failed': return NotificationType.paymentFailed;
      case 'payment': return NotificationType.payment;
      case 'chat_message': return NotificationType.chatMessage;
      case 'new_message': return NotificationType.newMessage;
      case 'review_received': return NotificationType.reviewReceived;
      case 'review': return NotificationType.review;
      case 'dispute_opened': return NotificationType.disputeOpened;
      case 'dispute_resolved': return NotificationType.disputeResolved;
      case 'verification_approved': return NotificationType.verificationApproved;
      case 'verification_rejected': return NotificationType.verificationRejected;
      case 'general': return NotificationType.general;
      case 'system': return NotificationType.system;
      default: return NotificationType.general;
    }
  }

  /// Categoria da tab onde o badge deve aparecer
  NotificationCategory get category {
    switch (this) {
      case NotificationType.chatMessage:
      case NotificationType.newMessage:
        return NotificationCategory.chat;
      case NotificationType.verificationApproved:
      case NotificationType.verificationRejected:
        return NotificationCategory.profile;
      case NotificationType.general:
      case NotificationType.system:
        return NotificationCategory.general;
      default:
        return NotificationCategory.jobs;
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.newJob: return 'Novo Serviço';
      case NotificationType.newCandidate: return 'Novo Candidato';
      case NotificationType.newQuote: return 'Nova Proposta';
      case NotificationType.quoteAccepted: return 'Proposta Aceita';
      case NotificationType.quoteRejected: return 'Proposta Rejeitada';
      case NotificationType.jobStarted: return 'Serviço Iniciado';
      case NotificationType.jobAccepted: return 'Serviço Aceito';
      case NotificationType.jobCompleted: return 'Serviço Concluído';
      case NotificationType.jobCancelled: return 'Serviço Cancelado';
      case NotificationType.jobStatus: return 'Atualização do Serviço';
      case NotificationType.paymentReceived: return 'Pagamento Recebido';
      case NotificationType.paymentConfirmed: return 'Pagamento Confirmado';
      case NotificationType.paymentFailed: return 'Pagamento Falhou';
      case NotificationType.payment: return 'Pagamento';
      case NotificationType.chatMessage: return 'Nova Mensagem';
      case NotificationType.newMessage: return 'Nova Mensagem';
      case NotificationType.reviewReceived: return 'Nova Avaliação';
      case NotificationType.review: return 'Avaliação';
      case NotificationType.disputeOpened: return 'Disputa Aberta';
      case NotificationType.disputeResolved: return 'Disputa Resolvida';
      case NotificationType.verificationApproved: return 'Verificação Aprovada';
      case NotificationType.verificationRejected: return 'Verificação Rejeitada';
      case NotificationType.general: return 'Notificação';
      case NotificationType.system: return 'Sistema';
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

  /// String do tipo (column ou data fallback)
  String get typeString {
    if (type != null) return type!.value;
    return (data?['type'] as String?) ?? 'general';
  }
}
