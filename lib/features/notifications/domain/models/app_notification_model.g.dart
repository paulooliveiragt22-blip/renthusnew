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
  NotificationType.newCandidate: 'newCandidate',
  NotificationType.newQuote: 'newQuote',
  NotificationType.quoteAccepted: 'quoteAccepted',
  NotificationType.quoteRejected: 'quoteRejected',
  NotificationType.jobStarted: 'jobStarted',
  NotificationType.jobAccepted: 'jobAccepted',
  NotificationType.jobCompleted: 'jobCompleted',
  NotificationType.jobCancelled: 'jobCancelled',
  NotificationType.jobStatus: 'jobStatus',
  NotificationType.paymentReceived: 'paymentReceived',
  NotificationType.paymentConfirmed: 'paymentConfirmed',
  NotificationType.paymentFailed: 'paymentFailed',
  NotificationType.payment: 'payment',
  NotificationType.chatMessage: 'chatMessage',
  NotificationType.newMessage: 'newMessage',
  NotificationType.reviewReceived: 'reviewReceived',
  NotificationType.review: 'review',
  NotificationType.disputeOpened: 'disputeOpened',
  NotificationType.disputeResolved: 'disputeResolved',
  NotificationType.verificationApproved: 'verificationApproved',
  NotificationType.verificationRejected: 'verificationRejected',
  NotificationType.general: 'general',
  NotificationType.system: 'system',
};
