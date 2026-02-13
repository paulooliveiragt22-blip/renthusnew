// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClientImpl _$$ClientImplFromJson(Map<String, dynamic> json) => _$ClientImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      cpf: json['cpf'] as String?,
      addressStreet: json['addressStreet'] as String?,
      addressNumber: json['addressNumber'] as String?,
      addressDistrict: json['addressDistrict'] as String?,
      addressZipCode: json['addressZipCode'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phoneVerified: json['phoneVerified'] as bool?,
      emailVerified: json['emailVerified'] as bool?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ClientImplToJson(_$ClientImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'city': instance.city,
      'state': instance.state,
      'cpf': instance.cpf,
      'addressStreet': instance.addressStreet,
      'addressNumber': instance.addressNumber,
      'addressDistrict': instance.addressDistrict,
      'addressZipCode': instance.addressZipCode,
      'photoUrl': instance.photoUrl,
      'phoneVerified': instance.phoneVerified,
      'emailVerified': instance.emailVerified,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$ProviderImpl _$$ProviderImplFromJson(Map<String, dynamic> json) =>
    _$ProviderImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      cpf: json['cpf'] as String?,
      cnpj: json['cnpj'] as String?,
      addressStreet: json['addressStreet'] as String?,
      addressNumber: json['addressNumber'] as String?,
      addressDistrict: json['addressDistrict'] as String?,
      addressZipCode: json['addressZipCode'] as String?,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      phoneVerified: json['phoneVerified'] as bool?,
      emailVerified: json['emailVerified'] as bool?,
      documentsVerified: json['documentsVerified'] as bool?,
      status: $enumDecodeNullable(_$ProviderStatusEnumMap, json['status']),
      phoneVisibility: json['phoneVisibility'] as bool? ?? true,
      emailVisibility: json['emailVisibility'] as bool? ?? true,
      addressVisibility: json['addressVisibility'] as bool? ?? true,
      totalJobs: (json['totalJobs'] as num?)?.toInt(),
      completedJobs: (json['completedJobs'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewsCount: (json['reviewsCount'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ProviderImplToJson(_$ProviderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'city': instance.city,
      'state': instance.state,
      'cpf': instance.cpf,
      'cnpj': instance.cnpj,
      'addressStreet': instance.addressStreet,
      'addressNumber': instance.addressNumber,
      'addressDistrict': instance.addressDistrict,
      'addressZipCode': instance.addressZipCode,
      'photoUrl': instance.photoUrl,
      'bio': instance.bio,
      'phoneVerified': instance.phoneVerified,
      'emailVerified': instance.emailVerified,
      'documentsVerified': instance.documentsVerified,
      'status': instance.status,
      'phoneVisibility': instance.phoneVisibility,
      'emailVisibility': instance.emailVisibility,
      'addressVisibility': instance.addressVisibility,
      'totalJobs': instance.totalJobs,
      'completedJobs': instance.completedJobs,
      'rating': instance.rating,
      'reviewsCount': instance.reviewsCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$ProviderStatusEnumMap = {
  ProviderStatus.active: 'active',
  ProviderStatus.inactive: 'inactive',
  ProviderStatus.suspended: 'suspended',
  ProviderStatus.pendingVerification: 'pendingVerification',
};
