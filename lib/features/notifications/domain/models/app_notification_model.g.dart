// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppNotificationImpl _$$AppNotificationImplFromJson(
        Map<String, dynamic> json) =>
    _$AppNotificationImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: $enumDecodeNullable(_$NotificationTypeEnumMap, json['type']),
      imageUrl: json['imageUrl'] as String?,
      actionUrl: json['actionUrl'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$AppNotificationImplToJson(
        _$AppNotificationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'body': instance.body,
      'type': instance.type,
      'imageUrl': instance.imageUrl,
      'actionUrl': instance.actionUrl,
      'data': instance.data,
      'isRead': instance.isRead,
      'readAt': instance.readAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$NotificationTypeEnumMap = {
  NotificationType.newJob: 'newJob',
  NotificationType.newMessage: 'newMessage',
  NotificationType.jobAccepted: 'jobAccepted',
  NotificationType.jobCompleted: 'jobCompleted',
  NotificationType.jobCancelled: 'jobCancelled',
  NotificationType.payment: 'payment',
  NotificationType.review: 'review',
  NotificationType.system: 'system',
};
