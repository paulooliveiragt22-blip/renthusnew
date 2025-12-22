class Conversation {
  final String id;
  final String jobId;
  final String clientId;
  final String providerId;
  final String title;
  final String status;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.jobId,
    required this.clientId,
    required this.providerId,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    // garante título NUNCA nullo ou vazio
    String safeTitle = (map['title'] as String?)?.trim() ?? '';
    if (safeTitle.isEmpty) {
      safeTitle = 'Chat do serviço';
    }

    return Conversation(
      id: map['id']?.toString() ?? '',
      jobId: map['job_id']?.toString() ?? '',
      clientId: map['client_id']?.toString() ?? '',
      providerId: map['provider_id']?.toString() ?? '',
      title: safeTitle,
      status: (map['status'] as String?) ?? 'active',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
