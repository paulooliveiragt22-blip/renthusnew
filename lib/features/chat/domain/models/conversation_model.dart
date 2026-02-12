import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_model.freezed.dart';
part 'conversation_model.g.dart';

/// Model de Conversa/Chat
@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required String jobId,
    required String clientId,
    required String providerId,
    String? lastMessage,
    DateTime? lastMessageAt,
    @Default(0) int unreadCount,
    @Default(false) bool isActive,
    
    // Campos calculados (vêm das views)
    String? jobTitle,
    String? clientName,
    String? clientPhotoUrl,
    String? providerName,
    String? providerPhotoUrl,
    
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);

  factory Conversation.fromMap(Map<String, dynamic> map) {
    final lastMsg = map['last_message'] ?? map['last_message_content'];
    final lastAtRaw =
        map['last_message_at'] ?? map['last_message_created_at'];
    return Conversation(
      id: map['id'] as String,
      jobId: map['job_id'] as String? ?? '',
      clientId: map['client_id'] as String,
      providerId: map['provider_id'] as String,
      lastMessage: lastMsg as String?,
      lastMessageAt: lastAtRaw != null
          ? DateTime.tryParse(lastAtRaw.toString()) ?? DateTime.now()
          : null,
      unreadCount: map['unread_count'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? false,
      jobTitle: (map['job_title'] ?? map['title']) as String?,
      clientName: map['client_name'] as String?,
      clientPhotoUrl: map['client_photo_url'] as String?,
      providerName: map['provider_name'] as String?,
      providerPhotoUrl: map['provider_photo_url'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }
}

/// Extension para helpers
extension ConversationX on Conversation {
  /// Tem mensagens não lidas?
  bool get hasUnread => unreadCount > 0;

  /// Último horário formatado
  String get lastMessageTimeFormatted {
    if (lastMessageAt == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(lastMessageAt!);
    
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    
    return '${lastMessageAt!.day}/${lastMessageAt!.month}';
  }

  /// Nome da outra pessoa (baseado em quem está logado)
  String getOtherPersonName(String currentUserId) {
    if (currentUserId == clientId) {
      return providerName ?? 'Prestador';
    }
    return clientName ?? 'Cliente';
  }

  /// Foto da outra pessoa
  String? getOtherPersonPhoto(String currentUserId) {
    if (currentUserId == clientId) {
      return providerPhotoUrl;
    }
    return clientPhotoUrl;
  }
}
