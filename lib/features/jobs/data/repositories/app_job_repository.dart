import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:path/path.dart' as p;
import 'package:renthus/utils/image_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositório unificado de JOBS (CLIENT + PROVIDER) - views v_* + RPCs.
class AppJobRepository {
  AppJobRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  // ============================================================
  // CLIENT - LEITURAS (VIEWS)
  // ============================================================

  Future<List<Map<String, dynamic>>> getClientJobs() async {
    final res = await _client
        .from('v_client_jobs')
        .select('*')
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> getClientJobById(String jobId) async {
    final res = await _client
        .from('v_client_jobs')
        .select('*')
        .eq('id', jobId)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> getClientJobCandidates(
    String jobId,
  ) async {
    final res = await _client
        .from('v_client_job_candidates')
        .select('*')
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getClientJobQuotes(String jobId) async {
    final res = await _client
        .from('v_client_job_quotes')
        .select('*')
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getClientJobPayments(String jobId) async {
    final res = await _client
        .from('v_client_job_payments')
        .select('*')
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Jobs recentes do cliente com status waiting_providers (para home)
  Future<List<Map<String, dynamic>>> getClientRecentJobsWaitingProviders(
    String clientId,
  ) async {
    final res = await _client
        .from('jobs')
        .select('id, title, status, created_at')
        .eq('client_id', clientId)
        .eq('status', 'waiting_providers')
        .order('created_at', ascending: false)
        .limit(20);
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Perfil/endereço do cliente (view segura).
  /// Se você ainda não criou essa view, esse método pode falhar.
  Future<Map<String, dynamic>?> getMyClientProfileAddress() async {
    final res = await _client
        .from('v_client_profile_address')
        .select(
          'address_zip_code, address_street, address_number, '
          'address_district, city, address_state',
        )
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  /// Geocode de endereço via Edge Function
  Future<({bool found, double? lat, double? lng})> geocodeAddress(
    String address, {
    String? district,
    String? city,
    String? state,
  }) async {
    try {
      final body = <String, dynamic>{'query': address};
      if (district != null && district.isNotEmpty) body['district'] = district;
      if (city != null && city.isNotEmpty) body['city'] = city;
      if (state != null && state.isNotEmpty) body['state'] = state;
      final res = await _client.functions.invoke(
        'geocode-address',
        body: body,
      );
      final data = res.data as Map?;
      final found = data?['found'] == true;
      final lat = (data?['lat'] as num?)?.toDouble();
      final lng = (data?['lng'] as num?)?.toDouble();
      return (found: found, lat: lat, lng: lng);
    } on FunctionException catch (_) {
      return (found: false, lat: null, lng: null);
    } catch (_) {
      return (found: false, lat: null, lng: null);
    }
  }

  /// Helper: existe pagamento paid para o job?
  Future<bool> hasPaidPaymentForJob(String jobId) async {
    final res = await _client
        .from('v_client_job_payments')
        .select('job_id')
        .eq('job_id', jobId)
        .eq('status', 'paid')
        .maybeSingle();

    return res != null;
  }

  // ============================================================
  // CLIENT - ESCRITAS (RPC)
  // ============================================================

  /// Cria job + endereço via RPC public.create_job(...)
  /// Retorna UUID (job_id).
  Future<String> createJobViaRpc({
    required String serviceTypeId,
    required String categoryId,
    required String title,
    required String description,
    required String serviceDetected,
    required String street,
    required String number,
    required String district,
    required String city,
    required String state,
    String? zipcode,
    double? lat,
    double? lng,
    DateTime? scheduledDate,
    TimeOfDay? scheduledStartTime,
    TimeOfDay? scheduledEndTime,
    bool hasFlexibleSchedule = true,
  }) async {
    String? dateStr;
    if (scheduledDate != null) {
      dateStr = '${scheduledDate.year}-'
          '${scheduledDate.month.toString().padLeft(2, '0')}-'
          '${scheduledDate.day.toString().padLeft(2, '0')}';
    }
    String? startStr;
    if (scheduledStartTime != null) {
      startStr = '${scheduledStartTime.hour.toString().padLeft(2, '0')}:'
          '${scheduledStartTime.minute.toString().padLeft(2, '0')}';
    }
    String? endStr;
    if (scheduledEndTime != null) {
      endStr = '${scheduledEndTime.hour.toString().padLeft(2, '0')}:'
          '${scheduledEndTime.minute.toString().padLeft(2, '0')}';
    }

    final res = await _client.rpc(
      'create_job',
      params: {
        'p_service_type_id': serviceTypeId,
        'p_category_id': categoryId,
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_service_detected': serviceDetected.trim(),
        'p_street': street.trim(),
        'p_number': number.trim(),
        'p_district': district.trim(),
        'p_city': city.trim(),
        'p_state': state.trim(),
        'p_zipcode': zipcode?.trim(),
        'p_lat': lat,
        'p_lng': lng,
        'p_scheduled_date': dateStr,
        'p_scheduled_start_time': startStr,
        'p_scheduled_end_time': endStr,
        'p_has_flexible_schedule': hasFlexibleSchedule,
      },
    );

    if (res is String && res.isNotEmpty) return res;

    if (res is Map && res.isNotEmpty) {
      final v = res['id'] ?? res['job_id'] ?? res['uuid'];
      if (v != null) return v.toString();
    }

    throw StateError('RPC create_job não retornou uuid válido: $res');
  }

  // ============================================================
  // PROVIDER - LEITURAS (VIEWS)
  // ============================================================

  Future<List<Map<String, dynamic>>> getProviderJobsPublic() async {
    final res = await _client
        .from('v_provider_jobs_public')
        .select('*')
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> getProviderJobPublicById(String jobId) async {
    final res = await _client
        .from('v_provider_jobs_public')
        .select('*')
        .eq('id', jobId)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>?> getProviderJobCandidatePendingById(
    String jobId,
  ) async {
    final res = await _client
        .from('v_provider_jobs_candidate_pending')
        .select('*')
        .eq('id', jobId)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> getProviderJobsAccepted() async {
    final res = await _client
        .from('v_provider_jobs_accepted')
        .select('*')
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> getProviderJobAcceptedById(String jobId) async {
    final res = await _client
        .from('v_provider_jobs_accepted')
        .select('*')
        .eq('id', jobId)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  /// Tenta accepted primeiro, senão public.
  Future<Map<String, dynamic>?> getProviderJobSmartById(String jobId) async {
    final accepted = await getProviderJobAcceptedById(jobId);
    if (accepted != null) return accepted;

    final candidatePending = await getProviderJobCandidatePendingById(jobId);
    if (candidatePending != null) return candidatePending;

    return getProviderJobPublicById(jobId);
  }

  // ============================================================
  // PROVIDER - ESCRITAS (RPC)
  // ============================================================

  /// ⚠️ Método antigo (mantido por compatibilidade).
  /// Seu banco NÃO aceita status='candidate' na job_candidates (CHECK).
  /// Então: tenta chamar a RPC antiga; se falhar por CHECK, faz fallback seguro.
  Future<void> becomeCandidate({required String jobId}) async {
    try {
      await _client.rpc('become_candidate', params: {'p_job_id': jobId});
      return;
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final isStatusCheck = msg.contains('job_candidates_status_check') ||
          msg.contains('violates check constraint');

      if (!isStatusCheck) rethrow;

      // Fallback: garante candidatura via RPC nova (sem quote)
      // (não cria quote porque approximate_price=0 e message=null)
      await submitJobQuote(
        jobId: jobId,
        approximatePrice: 0,
        message: null,
      );
    }
  }

  /// Método antigo (mantido).
  /// Use preferencialmente submitJobQuote() para garantir candidatura + quote juntos.
  Future<void> createJobQuote({
    required String jobId,
    required double approximatePrice,
    String message = '',
  }) async {
    await _client.rpc(
      'create_job_quote',
      params: {
        'p_job_id': jobId,
        'p_approximate_price': approximatePrice,
        'p_message': message,
      },
    );
  }

  Future<void> submitJobQuote({
    required String jobId,
    required double approximatePrice,
    String? message,
    DateTime? proposedStartAt,
    DateTime? proposedEndAt,
    int? estimatedDurationMinutes,
    DateTime? proposedDate,
    TimeOfDay proposedStartTime = const TimeOfDay(hour: 8, minute: 0),
    TimeOfDay proposedEndTime = const TimeOfDay(hour: 12, minute: 0),
  }) async {
    String? startAtStr;
    String? endAtStr;
    String? dateStr;
    String? startTimeStr;
    String? endTimeStr;

    if (proposedStartAt != null) {
      startAtStr = proposedStartAt.toUtc().toIso8601String();
      endAtStr = proposedEndAt?.toUtc().toIso8601String();

      dateStr = '${proposedStartAt.year}-'
          '${proposedStartAt.month.toString().padLeft(2, '0')}-'
          '${proposedStartAt.day.toString().padLeft(2, '0')}';
      startTimeStr = '${proposedStartAt.hour.toString().padLeft(2, '0')}:'
          '${proposedStartAt.minute.toString().padLeft(2, '0')}';
      if (proposedEndAt != null) {
        endTimeStr = '${proposedEndAt.hour.toString().padLeft(2, '0')}:'
            '${proposedEndAt.minute.toString().padLeft(2, '0')}';
      }
    } else if (proposedDate != null) {
      dateStr = '${proposedDate.year}-'
          '${proposedDate.month.toString().padLeft(2, '0')}-'
          '${proposedDate.day.toString().padLeft(2, '0')}';
      startTimeStr = '${proposedStartTime.hour.toString().padLeft(2, '0')}:'
          '${proposedStartTime.minute.toString().padLeft(2, '0')}';
      endTimeStr = '${proposedEndTime.hour.toString().padLeft(2, '0')}:'
          '${proposedEndTime.minute.toString().padLeft(2, '0')}';
    }

    await _client.rpc(
      'submit_job_quote',
      params: {
        'p_job_id': jobId,
        'p_approximate_price': approximatePrice,
        'p_message': (message ?? '').trim().isEmpty ? null : message!.trim(),
        'p_proposed_date': dateStr,
        'p_proposed_start_time': startTimeStr,
        'p_proposed_end_time': endTimeStr,
        'p_estimated_duration_minutes': estimatedDurationMinutes,
        'p_proposed_start_at': startAtStr,
        'p_proposed_end_at': endAtStr,
      },
    );
  }

  Future<Map<String, dynamic>> providerAcceptJobForQuote({
    required String jobId,
  }) async {
    final res = await _client.rpc(
      'provider_accept_job_for_quote',
      params: {'p_job_id': jobId},
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is String && res.isNotEmpty) {
      return {'accepted': true, 'message': res};
    }
    return {'accepted': true};
  }

  Future<void> providerSetJobStatus({
    required String jobId,
    required String newStatus,
    int? etaMinutes,
  }) async {
    await _client.rpc(
      'provider_set_job_status',
      params: {
        'p_job_id': jobId,
        'p_new_status': newStatus,
        'p_eta_minutes': etaMinutes,
      },
    );
  }

  // ============================================================
  // FOTOS (Storage + RPC add_job_photo)
  // ============================================================

  Future<void> uploadJobPhotos({
    required String jobId,
    required List<File> files,
    int maxPhotos = 3,
  }) async {
    const String bucket = 'job-photos';

    final toUpload =
        files.length > maxPhotos ? files.take(maxPhotos).toList() : files;

    for (final file in toUpload) {
      final Uint8List rawBytes = await file.readAsBytes();
      final compressed = await ImageUtils.compressWithThumb(rawBytes);

      final originalName = file.path.split(RegExp(r'[\/\\]')).last;
      String ext = p.extension(originalName);
      if (ext.isEmpty) ext = '.jpg';

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final mainPath = '$jobId/${timestamp}_full$ext';
      final thumbPath = '$jobId/${timestamp}_thumb$ext';

      await _client.storage
          .from(bucket)
          .uploadBinary(mainPath, compressed.mainBytes);
      final publicUrl = _client.storage.from(bucket).getPublicUrl(mainPath);

      await _client.storage
          .from(bucket)
          .uploadBinary(thumbPath, compressed.thumbBytes);
      final thumbUrl = _client.storage.from(bucket).getPublicUrl(thumbPath);

      await _client.rpc(
        'add_job_photo',
        params: {
          'p_job_id': jobId,
          'p_url': publicUrl,
          'p_thumb_url': thumbUrl,
        },
      );
    }
  }

  Future<void> uploadJobDocuments({
    required String jobId,
    required List<File> files,
    int maxDocuments = 5,
  }) async {
    const String bucket = 'job-photos';
    final toUpload =
        files.length > maxDocuments ? files.take(maxDocuments).toList() : files;

    for (final file in toUpload) {
      final String originalName = file.path.split(RegExp(r'[\/\\]')).last;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String storagePath = '$jobId/docs/${timestamp}_$originalName';

      await _client.storage.from(bucket).upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _client.storage.from(bucket).getPublicUrl(storagePath);

      await _client.rpc(
        'add_job_document',
        params: {
          'p_job_id': jobId,
          'p_url': publicUrl,
          'p_filename': originalName,
          'p_mime_type': 'application/pdf',
        },
      );
    }
  }

  // ------------------------------------------------------------
  // DISPUTAS (RPC)
  // ------------------------------------------------------------

  Future<String> openDisputeForCurrentUser({
    required String jobId,
    required String description,
    DateTime? solutionDeadline,
  }) async {
    try {
      final res = await _client.rpc(
        'open_dispute_for_current_user',
        params: {
          'p_job_id': jobId,
          'p_description': description.trim(),
          'p_solution_deadline_at': solutionDeadline?.toUtc().toIso8601String(),
        },
      );

      if (res is String && res.isNotEmpty) return res;

      if (res is Map && res['id'] != null) {
        return res['id'].toString();
      }

      throw StateError(
        'RPC open_dispute_for_current_user não retornou id válido: $res',
      );
    } catch (e) {
      throw StateError(
        'Falha ao abrir disputa (RPC open_dispute_for_current_user): $e',
      );
    }
  }

  Future<void> resolveDisputeForJob(String jobId) async {
    try {
      await _client.rpc(
        'resolve_dispute_for_job',
        params: {
          'p_job_id': jobId,
        },
      );
    } catch (e) {
      throw StateError(
        'Falha ao resolver disputa (RPC resolve_dispute_for_job): $e',
      );
    }
  }
}
