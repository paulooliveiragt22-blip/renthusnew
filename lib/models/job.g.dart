// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$JobImpl _$$JobImplFromJson(Map<String, dynamic> json) => _$JobImpl(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      serviceTypeId: json['serviceTypeId'] as String,
      categoryId: json['categoryId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      serviceDetected: json['serviceDetected'] as String,
      status: $enumDecode(_$JobStatusEnumMap, json['status']),
      city: json['city'] as String,
      state: json['state'] as String,
      zipcode: json['zipcode'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      clientName: json['clientName'] as String?,
      clientPhone: json['clientPhone'] as String?,
      serviceTypeName: json['serviceTypeName'] as String?,
      categoryName: json['categoryName'] as String?,
      candidatesCount: (json['candidatesCount'] as num?)?.toInt(),
      quotesCount: (json['quotesCount'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      scheduledAt: json['scheduledAt'] == null
          ? null
          : DateTime.parse(json['scheduledAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
    );

Map<String, dynamic> _$$JobImplToJson(_$JobImpl instance) => <String, dynamic>{
      'id': instance.id,
      'clientId': instance.clientId,
      'serviceTypeId': instance.serviceTypeId,
      'categoryId': instance.categoryId,
      'title': instance.title,
      'description': instance.description,
      'serviceDetected': instance.serviceDetected,
      'status': instance.status,
      'city': instance.city,
      'state': instance.state,
      'zipcode': instance.zipcode,
      'lat': instance.lat,
      'lng': instance.lng,
      'clientName': instance.clientName,
      'clientPhone': instance.clientPhone,
      'serviceTypeName': instance.serviceTypeName,
      'categoryName': instance.categoryName,
      'candidatesCount': instance.candidatesCount,
      'quotesCount': instance.quotesCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'scheduledAt': instance.scheduledAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
    };

const _$JobStatusEnumMap = {
  JobStatus.open: 'open',
  JobStatus.pending: 'pending',
  JobStatus.assigned: 'assigned',
  JobStatus.inProgress: 'inProgress',
  JobStatus.completed: 'completed',
  JobStatus.cancelled: 'cancelled',
};
