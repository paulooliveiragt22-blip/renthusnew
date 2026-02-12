import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

/// Model de Mensagem
@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String conversationId,
    required String senderId,
    required String content,
    MessageType? type,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    @Default(false) bool isRead,
    DateTime? readAt,
    
    // Campos calculados
    String? senderName,
    String? senderPhotoUrl,
    
    required DateTime createdAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      type: map['type'] != null 
          ? MessageType.fromString(map['type'] as String)
          : MessageType.text,
      imageUrl: map['image_url'] as String?,
      fileUrl: map['file_url'] as String?,
      fileName: map['file_name'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      senderName: map['sender_name'] as String?,
      senderPhotoUrl: map['sender_photo_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Tipo de mensagem
enum MessageType {
  text,
  image,
  file;

  String toJson() => name;

  static MessageType fromString(String value) {
    switch (value) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }
}

/// Extension para helpers
extension MessageX on Message {
  /// É mensagem de texto?
  bool get isText => type == MessageType.text;

  /// É mensagem com imagem?
  bool get isImage => type == MessageType.image;

  /// É mensagem com arquivo?
  bool get isFile => type == MessageType.file;

  /// Horário formatado
  String get timeFormatted {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// É mensagem do usuário atual?
  bool isMine(String currentUserId) {
    return senderId == currentUserId;
  }
}
