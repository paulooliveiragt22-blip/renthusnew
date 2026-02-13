import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/shared_preferences_provider.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/jobs/data/repositories/job_repository.dart';
import 'package:renthus/features/jobs/domain/models/client_job_details_model.dart';
import 'package:renthus/features/jobs/domain/models/client_my_jobs_model.dart';
import 'package:renthus/features/jobs/domain/models/provider_my_jobs_model.dart';
import 'package:renthus/features/notifications/data/providers/notification_providers.dart';
import 'package:renthus/models/job.dart';
import 'package:renthus/repositories/Chat_Repository.dart' as legacy_chat;
import 'package:renthus/repositories/job_repository.dart' as app_repo;

part 'job_providers.g.dart';

/// Repositório legado de chat (upsertConversationForJob, etc.)
@riverpod
legacy_chat.ChatRepository legacyChatRepository(
    LegacyChatRepositoryRef ref) {
  return legacy_chat.ChatRepository();
}

String _mapStatusLabel(String status) {
  switch (status) {
    case 'waiting_providers':
    case 'open':
      return 'Disponível';
    case 'accepted':
      return 'Aguardando início';
    case 'on_the_way':
      return 'A caminho';
    case 'in_progress':
      return 'Em execução';
    case 'execution_overdue':
      return 'Fora do prazo';
    case 'completed':
      return 'Finalizado';
    case 'dispute':
    case 'dispute_open':
      return 'Em disputa';
    case 'refunded':
      return 'Estornado';
    case 'cancelled':
      return 'Cancelado';
    case 'cancelled_by_client':
      return 'Cancelado pelo cliente';
    case 'cancelled_by_provider':
      return 'Cancelado por você';
    default:
      return status.isEmpty ? 'Indefinido' : status;
  }
}

Color _mapStatusColor(String status) {
  switch (status) {
    case 'waiting_providers':
    case 'open':
      return Colors.blueGrey;
    case 'accepted':
    case 'on_the_way':
    case 'in_progress':
      return const Color(0xFF34A853);
    case 'execution_overdue':
      return Colors.red;
    case 'completed':
      return const Color(0xFF3B246B);
    case 'dispute':
    case 'dispute_open':
      return const Color(0xFFFF3B30);
    case 'refunded':
      return const Color(0xFF0DAA00);
    case 'cancelled':
    case 'cancelled_by_client':
    case 'cancelled_by_provider':
      return Colors.red.shade600;
    default:
      return Colors.grey.shade700;
  }
}

@riverpod
JobRepository jobRepository(JobRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return JobRepository(supabase);
}

/// Repositório legado (views v_provider_jobs_*) para job_details do prestador
@riverpod
app_repo.JobRepository appJobRepository(AppJobRepositoryRef ref) {
  return app_repo.JobRepository();
}

/// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
@riverpod
Future<Map<String, dynamic>?> providerJobById(
    ProviderJobByIdRef ref, String jobId) async {
  final repo = ref.read(appJobRepositoryProvider);
  return await repo.getProviderJobSmartById(jobId);
}

/// Lista de jobs públicos para home do prestador (v_provider_jobs_public)
@riverpod
Future<List<Map<String, dynamic>>> providerJobsPublic(
    ProviderJobsPublicRef ref) async {
  final repo = ref.read(appJobRepositoryProvider);
  return await repo.getProviderJobsPublic();
}

/// Dados do header do prestador (v_provider_me)
@riverpod
Future<Map<String, dynamic>?> providerMe(ProviderMeRef ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final me = await supabase.from('v_provider_me').select('''
    full_name, city, is_verified, documents_verified, verified, status
  ''').maybeSingle();

  if (me == null) return null;
  return Map<String, dynamic>.from(me as Map);
}

/// Banners ativos (partner_banners) com URLs resolvidas
@riverpod
Future<List<Map<String, dynamic>>> providerBanners(
    ProviderBannersRef ref) async {
  final supabase = ref.watch(supabaseProvider);
  final rows = await supabase
      .from('partner_banners')
      .select('title, subtitle, image_path, action_type, action_value')
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  final List<Map<String, dynamic>> list = [];
  for (final row in rows as List<dynamic>) {
    final r = Map<String, dynamic>.from(row as Map);
    final rawPath = ((r['image_path'] as String?) ?? '').trim();
    String imageUrl = rawPath;
    if (rawPath.isNotEmpty &&
        !rawPath.startsWith('http://') &&
        !rawPath.startsWith('https://')) {
      final cleaned =
          rawPath.startsWith('banners/') ? rawPath.substring(8) : rawPath;
      imageUrl = supabase.storage.from('banners').getPublicUrl(cleaned);
    }
    list.add({
      'title': r['title'] ?? '',
      'subtitle': r['subtitle'],
      'imageUrl': imageUrl,
      'actionType': r['action_type'],
      'actionValue': r['action_value'],
    });
  }
  return list;
}

/// Jobs + disputas do prestador com filtro de período (v_provider_my_jobs + v_provider_disputes)
@riverpod
Future<ProviderMyJobsResult> providerMyJobs(
    ProviderMyJobsRef ref, int selectedDays) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) {
    return const ProviderMyJobsResult(
      allItems: [],
      newServicesItems: [],
      inProgressItems: [],
      completedItems: [],
      disputeItems: [],
      cancelledItems: [],
      countNewServices: 0,
      countInProgress: 0,
      countCompleted: 0,
      countDisputes: 0,
      countCancelled: 0,
    );
  }

  final since =
      DateTime.now().toUtc().subtract(Duration(days: selectedDays));
  final sinceStr = since.toIso8601String();
  final currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // 1) Unread messages (legacy schema: read, channel)
  Map<String, int> unreadByJobId = {};
  try {
    final notifRes = await supabase
        .from('notifications')
        .select('data')
        .eq('user_id', user.id)
        .eq('channel', 'app')
        .eq('read', false);

    for (final row in notifRes as List<dynamic>) {
      final data = row['data'];
      if (data is Map) {
        if (data['type']?.toString() != 'chat_message') continue;
        final jobId = data['job_id']?.toString();
        if (jobId != null) {
          unreadByJobId[jobId] = (unreadByJobId[jobId] ?? 0) + 1;
        }
      }
    }
  } catch (_) {}

  // 2) Jobs (v_provider_my_jobs)
  final jobsRes = await supabase
      .from('v_provider_my_jobs')
      .select('*')
      .gte('created_at', sinceStr)
      .order('created_at', ascending: false);

  final List<JobCardData> jobCards = [];
  for (final j in jobsRes as List<dynamic>) {
    final jobId = j['job_id']?.toString() ?? '';
    if (jobId.isEmpty) continue;

    final rawStatus = j['status']?.toString() ?? '';
    final uiGroup = j['ui_group']?.toString() ?? 'waitingClient';

    final createdAt = DateTime.tryParse(
          (j['candidate_created_at'] ?? j['created_at']).toString(),
        )?.toLocal() ??
        DateTime.now();

    final amountProvider = j['amount_provider'];
    final priceLabel = amountProvider != null
        ? currencyFormatter.format((amountProvider as num).toDouble())
        : '';

    jobCards.add(JobCardData(
      jobId: jobId,
      jobCode: j['job_code']?.toString() ?? 'Serviço',
      description: j['description']?.toString() ?? '',
      priceLabel: priceLabel,
      rawStatus: rawStatus,
      statusLabel: _mapStatusLabel(rawStatus),
      statusColor: _mapStatusColor(rawStatus),
      dateLabel: DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
      sortDate: createdAt,
      unreadMessages: unreadByJobId[jobId] ?? 0,
      group: uiGroup == 'active'
          ? ProviderJobGroup.active
          : uiGroup == 'history'
              ? ProviderJobGroup.history
              : ProviderJobGroup.waitingClient,
      openAsDispute: false,
    ));
  }

  // 3) Disputes (v_provider_disputes)
  String shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  final disputesRes = await supabase
      .from('v_provider_disputes')
      .select(
        'dispute_id, job_id, dispute_status, dispute_description, dispute_created_at',
      )
      .gte('dispute_created_at', sinceStr)
      .order('dispute_created_at', ascending: false);

  final List<JobCardData> disputeCards = [];
  for (final d in disputesRes as List<dynamic>) {
    final jobId = d['job_id']?.toString() ?? '';
    if (jobId.isEmpty) continue;

    final createdAt = DateTime.tryParse(
          d['dispute_created_at']?.toString() ?? '',
        )?.toLocal() ??
        DateTime.now();

    disputeCards.add(JobCardData(
      jobId: jobId,
      jobCode: 'Disputa • ${shortId(jobId)}',
      description: d['dispute_description']?.toString() ?? '',
      priceLabel: '',
      rawStatus: 'dispute',
      statusLabel: 'Em disputa',
      statusColor: const Color(0xFFFF3B30),
      dateLabel: DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
      sortDate: createdAt,
      unreadMessages: unreadByJobId[jobId] ?? 0,
      group: ProviderJobGroup.active,
      openAsDispute: true,
    ));
  }

  // 4) Consolidate
  final all = [...jobCards, ...disputeCards];

  // 5) Categorize
  final cancelled = all
      .where((e) =>
          e.rawStatus == 'cancelled' ||
          e.rawStatus == 'cancelled_by_client' ||
          e.rawStatus == 'cancelled_by_provider')
      .toList();
  final disputes = all.where((e) => e.openAsDispute).toList();
  final waitingClient =
      all.where((e) => e.group == ProviderJobGroup.waitingClient).toList();
  final active =
      all.where((e) => e.group == ProviderJobGroup.active).toList();
  final history =
      all.where((e) => e.group == ProviderJobGroup.history).toList();

  return ProviderMyJobsResult(
    allItems: all,
    newServicesItems: waitingClient,
    inProgressItems: active,
    completedItems: history,
    disputeItems: disputes,
    cancelledItems: cancelled,
    countNewServices: waitingClient.length,
    countInProgress: active.length,
    countCompleted: history.length,
    countDisputes: disputes.length,
    countCancelled: cancelled.length,
  );
}

/// Jobs do cliente (v_client_my_jobs_dashboard) com filtro de período
@riverpod
Future<ClientMyJobsResult> clientMyJobs(
    ClientMyJobsRef ref, int selectedDays) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Faça login novamente para ver seus pedidos.');
  }

  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final since =
      DateTime.now().toUtc().subtract(Duration(days: selectedDays));
  final sinceStr = since.toIso8601String();

  // 1) Disputas (sem filtro de dias)
  final disputesRes = await supabase
      .from('v_client_my_jobs_dashboard')
      .select('''
        job_id, title, description, status, created_at, job_code,
        quotes_count, new_candidates_count, dispute_status
      ''')
      .or('dispute_status.eq.open,dispute_status.eq.resolved')
      .order('created_at', ascending: false);

  // 2) Demais jobs (com filtro de dias)
  final jobsRes = await supabase
      .from('v_client_my_jobs_dashboard')
      .select('''
        job_id, title, description, status, created_at, job_code,
        quotes_count, new_candidates_count, dispute_status
      ''')
      .gte('created_at', sinceStr)
      .not('dispute_status', 'in', '("open","resolved")')
      .order('created_at', ascending: false);

  final Map<String, Map<String, dynamic>> byId = {};
  for (final row in jobsRes as List<dynamic>) {
    final r = Map<String, dynamic>.from(row as Map);
    final id = r['job_id']?.toString();
    if (id != null) byId[id] = r;
  }
  for (final row in disputesRes as List<dynamic>) {
    final r = Map<String, dynamic>.from(row as Map);
    final id = r['job_id']?.toString();
    if (id != null) byId[id] = r;
  }

  final rows = byId.values.toList();
  final normalized = <Map<String, dynamic>>[];

  for (final r in rows) {
    final jobId = r['job_id']?.toString();
    if (jobId == null || jobId.isEmpty) continue;

    final totalQuotes = (r['quotes_count'] as num?)?.toInt() ?? 0;
    final totalCandidates =
        (r['new_candidates_count'] as num?)?.toInt() ?? 0;
    final seen = prefs.getInt('client_seen_candidates_$jobId') ?? 0;
    int delta = totalCandidates - seen;
    if (delta < 0) delta = 0;

    normalized.add({
      ...r,
      'id': jobId,
      'quotes_count': totalQuotes,
      'candidates_total': totalCandidates,
      'new_candidates_count': delta,
      'dispute_status': (r['dispute_status'] as String?) ?? '',
    });
  }

  final requested = <Map<String, dynamic>>[];
  final inProgress = <Map<String, dynamic>>[];
  final completed = <Map<String, dynamic>>[];
  final cancelled = <Map<String, dynamic>>[];
  final disputes = <Map<String, dynamic>>[];

  for (final j in normalized) {
    final status = (j['status'] as String?) ?? '';
    final disputeStatus = (j['dispute_status'] as String?) ?? '';

    if (disputeStatus == 'open' || disputeStatus == 'resolved') {
      disputes.add(j);
      continue;
    }
    if (status == 'open' || status == 'waiting_providers') {
      requested.add(j);
      continue;
    }
    if (['accepted', 'on_the_way', 'in_progress', 'execution_overdue']
        .contains(status)) {
      inProgress.add(j);
      continue;
    }
    if (['completed', 'refunded'].contains(status)) {
      completed.add(j);
      continue;
    }
    if (['cancelled', 'cancelled_by_client', 'cancelled_by_provider']
        .contains(status)) {
      cancelled.add(j);
      continue;
    }
    inProgress.add(j);
  }

  requested.sort((a, b) {
    final aStatus = (a['status'] as String?) ?? '';
    final bStatus = (b['status'] as String?) ?? '';
    final aDelta = aStatus == 'waiting_providers'
        ? ((a['new_candidates_count'] as int?) ?? 0)
        : 0;
    final bDelta = bStatus == 'waiting_providers'
        ? ((b['new_candidates_count'] as int?) ?? 0)
        : 0;
    final aHas = aDelta > 0;
    final bHas = bDelta > 0;
    if (aHas != bHas) return bHas ? 1 : -1;
    final byDelta = bDelta.compareTo(aDelta);
    if (byDelta != 0) return byDelta;
    final aDt =
        DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
    final bDt =
        DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
    return bDt.compareTo(aDt);
  });

  return ClientMyJobsResult(
    requestedItems: requested,
    inProgressItems: inProgress,
    completedItems: completed,
    cancelledItems: cancelled,
    disputeItems: disputes,
    countRequested: requested.length,
    countInProgress: inProgress.length,
    countCompleted: completed.length,
    countCancelled: cancelled.length,
    countDisputes: disputes.length,
  );
}

String _friendlyProviderName(String providerId) {
  if (providerId.isEmpty) return 'Profissional';
  if (providerId.length <= 6) return 'Profissional $providerId';
  return 'Profissional ${providerId.substring(0, 6)}…';
}

/// Detalhes do job para o cliente (v_client_jobs + v_client_job_quotes + v_client_job_payments)
@riverpod
Future<ClientJobDetailsResult> clientJobDetails(
    ClientJobDetailsRef ref, String jobId) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Faça login novamente para ver os detalhes do pedido.');
  }

  final appRepo = ref.read(appJobRepositoryProvider);

  final jobMap = await appRepo.getClientJobById(jobId);
  if (jobMap == null) {
    throw Exception('Pedido não encontrado.');
  }

  final clientId = (jobMap['client_id'] ?? '').toString();
  if (clientId.isNotEmpty && clientId != user.id) {
    throw Exception('Você não tem permissão para ver este pedido.');
  }

  final hasAnyDispute = (jobMap['is_disputed'] == true);
  final hasOpenDispute = (jobMap['dispute_open'] == true);

  bool hasPaid = false;
  Map<String, dynamic>? paymentRow;

  try {
    final payments = await appRepo.getClientJobPayments(jobId);
    if (payments.isNotEmpty) {
      paymentRow = payments.first;
      hasPaid = (paymentRow['status']?.toString() == 'paid');
    } else {
      hasPaid = (jobMap['payment_status']?.toString() == 'paid');
    }
  } catch (_) {
    hasPaid = (jobMap['payment_status']?.toString() == 'paid');
  }

  final quotesList = await appRepo.getClientJobQuotes(jobId);
  final approvedProviderId = jobMap['provider_id'] as String?;
  final hasApprovedProvider = approvedProviderId != null;

  final List<Map<String, dynamic>> finalCandidates = [];
  for (final q in quotesList) {
    final providerId = (q['provider_id'] ?? '').toString();
    if (providerId.isEmpty) continue;

    if (hasApprovedProvider && providerId != approvedProviderId) continue;

    finalCandidates.add({
      'provider_id': providerId,
      'provider_name': _friendlyProviderName(providerId),
      'provider_avatar_url': null,
      'created_at': q['created_at'],
      'quote_id': q['quote_id'],
      'approximate_price': q['approximate_price'],
      'quote_message': q['message'],
      'client_status': hasApprovedProvider ? 'approved' : 'pending',
    });
  }

  return ClientJobDetailsResult(
    job: jobMap,
    candidates: finalCandidates,
    hasOpenDispute: hasOpenDispute,
    hasAnyDispute: hasAnyDispute,
    hasPaid: hasPaid,
    payment: paymentRow,
  );
}

/// Jobs para painel admin (tabela jobs, limit 500)
@riverpod
Future<List<Map<String, dynamic>>> adminJobs(AdminJobsRef ref) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('jobs')
      .select(
        'id, title, status, created_at, client_id, provider_id, price, daily_total, payment_status',
      )
      .order('created_at', ascending: false)
      .limit(500);
  return (data as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// Contagem de notificações não lidas para a home do prestador (0 se não logado)
@riverpod
int providerHomeUnreadCount(ProviderHomeUnreadCountRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  return ref.watch(unreadNotificationsCountProvider(user.id)).valueOrNull ?? 0;
}

@riverpod
Future<List<Job>> jobsList(JobsListRef ref, {String? city, String? status}) async {
  final repository = ref.watch(jobRepositoryProvider);
  return await repository.getJobs(city: city, status: status);
}

@riverpod
Future<Job> jobById(JobByIdRef ref, String id) async {
  final repository = ref.watch(jobRepositoryProvider);
  return await repository.getJobById(id);
}

@riverpod
Stream<List<Job>> jobsStream(JobsStreamRef ref, {String? city}) {
  final repository = ref.watch(jobRepositoryProvider);
  return repository.watchJobs(city: city);
}

@riverpod
class JobActions extends _$JobActions {
  @override
  FutureOr<void> build() async {}

  Future<Job?> create(Map<String, dynamic> jobData) async {
    state = const AsyncValue.loading();
    
    return await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      final job = await repository.createJob(jobData);
      ref.invalidate(jobsListProvider);
      return job;
    }).then((result) => result.value);
  }

  Future<void> updateJob(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    
    state = await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      await repository.updateJob(id, updates);
      ref.invalidate(jobsListProvider);
      ref.invalidate(jobByIdProvider(id));
    });
  }
}
