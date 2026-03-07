class ConversationWithLastMessage {

  ConversationWithLastMessage({
    required this.conversationId,
    required this.jobId,
    required this.clientId,
    required this.providerId,
    required this.title,
    required this.status,
    required this.conversationCreatedAt,
    required this.lastMessageId,
    required this.lastMessageContent,
    required this.lastMessageCreatedAt,
    required this.lastMessageSenderId,
    required this.lastMessageSenderRole,
  });

  factory ConversationWithLastMessage.fromMap(Map<String, dynamic> map) {
    return ConversationWithLastMessage(
      conversationId: map['conversation_id'] as String,
      jobId: map['job_id'] as String,
      clientId: map['client_id'] as String,
      providerId: map['provider_id'] as String,
      title: map['title'] as String,
      status: map['status'] as String,
      conversationCreatedAt:
          DateTime.parse(map['conversation_created_at'] as String),
      lastMessageId: map['last_message_id'] as String?,
      lastMessageContent: map['last_message_content'] as String?,
      lastMessageCreatedAt: map['last_message_created_at'] != null
          ? DateTime.parse(map['last_message_created_at'] as String)
          : null,
      lastMessageSenderId: map['last_message_sender_id'] as String?,
      lastMessageSenderRole: map['last_message_sender_role'] as String?,
    );
  }
  final String conversationId;
  final String jobId;
  final String clientId;
  final String providerId;
  final String title;
  final String status;
  final DateTime conversationCreatedAt;

  final String? lastMessageId;
  final String? lastMessageContent;
  final DateTime? lastMessageCreatedAt;
  final String? lastMessageSenderId;
  final String? lastMessageSenderRole;
}
