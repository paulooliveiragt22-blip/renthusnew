// lib/models/job.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'job.freezed.dart';
part 'job.g.dart';

/// Model tipado para Job
/// 
/// Benefícios:
/// - Type safety (sem Map<String, dynamic>)
/// - Autocomplete no IDE
/// - Null safety garantido
/// - JSON serialization automática
/// - Immutability (segurança)
@freezed
class Job with _$Job {
  const factory Job({
    required String id,
    required String clientId,
    required String serviceTypeId,
    required String categoryId,
    required String title,
    required String description,
    required String serviceDetected,
    required JobStatus status,
    required String city,
    required String state,
    String? zipcode,
    double? lat,
    double? lng,
    
    // Campos calculados (vêm das views)
    String? clientName,
    String? clientPhone,
    String? serviceTypeName,
    String? categoryName,
    int? candidatesCount,
    int? quotesCount,
    
    // Timestamps
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? scheduledAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
  
  /// Helper para converter de Map (legacy)
  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      serviceTypeId: map['service_type_id'] as String,
      categoryId: map['category_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      serviceDetected: map['service_detected'] as String,
      status: JobStatus.fromString(map['status'] as String),
      city: map['city'] as String,
      state: map['state'] as String,
      zipcode: map['zipcode'] as String?,
      lat: map['lat'] as double?,
      lng: map['lng'] as double?,
      
      clientName: map['client_name'] as String?,
      clientPhone: map['client_phone'] as String?,
      serviceTypeName: map['service_type_name'] as String?,
      categoryName: map['category_name'] as String?,
      candidatesCount: map['candidates_count'] as int?,
      quotesCount: map['quotes_count'] as int?,
      
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : null,
      scheduledAt: map['scheduled_at'] != null
          ? DateTime.parse(map['scheduled_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      cancelledAt: map['cancelled_at'] != null
          ? DateTime.parse(map['cancelled_at'] as String)
          : null,
    );
  }
}

/// Enum para status do Job (type-safe)
enum JobStatus {
  open,
  pending,
  assigned,
  inProgress,
  completed,
  cancelled;

  String toJson() => name;

  static JobStatus fromString(String value) {
    switch (value) {
      case 'open':
        return JobStatus.open;
      case 'pending':
        return JobStatus.pending;
      case 'assigned':
        return JobStatus.assigned;
      case 'in_progress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        throw ArgumentError('Invalid JobStatus: $value');
    }
  }

  String get displayName {
    switch (this) {
      case JobStatus.open:
        return 'Aberto';
      case JobStatus.pending:
        return 'Avaliando';
      case JobStatus.assigned:
        return 'Aceito';
      case JobStatus.inProgress:
        return 'Em Andamento';
      case JobStatus.completed:
        return 'Concluído';
      case JobStatus.cancelled:
        return 'Cancelado';
    }
  }
  
  bool get isActive => this == JobStatus.open || this == JobStatus.pending;
  bool get isFinal => this == JobStatus.completed || this == JobStatus.cancelled;
}