// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

String _jobStatusToJson(JobStatus status) {
  switch (status) {
    case JobStatus.inProgress:
      return 'in_progress';
    default:
      return status.name;
  }
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$JobImpl _$$JobImplFromJson(Map<String, dynamic> json) => _$JobImpl(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      serviceTypeId: json['service_type_id'] as String,
      categoryId: json['category_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      serviceDetected: json['service_detected'] as String,
      status: JobStatus.fromString(json['status'] as String),
      city: json['city'] as String,
      state: json['state'] as String,
      zipcode: json['zipcode'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
      serviceTypeName: json['service_type_name'] as String?,
      categoryName: json['category_name'] as String?,
      candidatesCount: (json['candidates_count'] as num?)?.toInt(),
      quotesCount: (json['quotes_count'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      scheduledAt: json['scheduled_at'] == null
          ? null
          : DateTime.parse(json['scheduled_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
    );

Map<String, dynamic> _$$JobImplToJson(_$JobImpl instance) => <String, dynamic>{
      'id': instance.id,
      'client_id': instance.clientId,
      'service_type_id': instance.serviceTypeId,
      'category_id': instance.categoryId,
      'title': instance.title,
      'description': instance.description,
      'service_detected': instance.serviceDetected,
      'status': _jobStatusToJson(instance.status),
      'city': instance.city,
      'state': instance.state,
      'zipcode': instance.zipcode,
      'lat': instance.lat,
      'lng': instance.lng,
      'client_name': instance.clientName,
      'client_phone': instance.clientPhone,
      'service_type_name': instance.serviceTypeName,
      'category_name': instance.categoryName,
      'candidates_count': instance.candidatesCount,
      'quotes_count': instance.quotesCount,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'scheduled_at': instance.scheduledAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'cancelled_at': instance.cancelledAt?.toIso8601String(),
    };
