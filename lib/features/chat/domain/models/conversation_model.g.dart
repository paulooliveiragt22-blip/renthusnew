// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConversationImpl _$$ConversationImplFromJson(Map<String, dynamic> json) =>
    _$ConversationImpl(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      clientId: json['clientId'] as String,
      providerId: json['providerId'] as String,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      jobTitle: json['jobTitle'] as String?,
      clientName: json['clientName'] as String?,
      clientPhotoUrl: json['clientPhotoUrl'] as String?,
      providerName: json['providerName'] as String?,
      providerPhotoUrl: json['providerPhotoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ConversationImplToJson(_$ConversationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jobId': instance.jobId,
      'clientId': instance.clientId,
      'providerId': instance.providerId,
      'lastMessage': instance.lastMessage,
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'isActive': instance.isActive,
      'jobTitle': instance.jobTitle,
      'clientName': instance.clientName,
      'clientPhotoUrl': instance.clientPhotoUrl,
      'providerName': instance.providerName,
      'providerPhotoUrl': instance.providerPhotoUrl,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
