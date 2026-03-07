import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/cache_provider.dart';
import 'package:renthus/core/providers/shared_preferences_provider.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/auth/data/providers/auth_providers.dart';
import 'package:renthus/features/jobs/data/repositories/job_repository.dart';
import 'package:renthus/features/jobs/domain/models/client_job_details_model.dart';
import 'package:renthus/features/jobs/domain/models/client_my_jobs_model.dart';
import 'package:renthus/features/jobs/domain/models/provider_my_jobs_model.dart';
import 'package:renthus/features/notifications/data/providers/notification_providers.dart';
import 'package:renthus/models/job.dart';
import 'package:renthus/features/chat/data/repositories/legacy_chat_repository.dart';
import 'package:renthus/features/jobs/data/repositories/app_job_repository.dart';
import 'package:renthus/features/jobs/data/repositories/service_types_repository.dart';

part 'job_providers.g.dart';

@riverpod
ServiceTypesRepository serviceTypesRepository(
    ServiceTypesRepositoryRef ref) {
  return ServiceTypesRepository(client: ref.read(supabaseProvider));
}

/// Repositório legado de chat (upsertConversationForJob, etc.)
@riverpod
LegacyChatRepository legacyChatRepository(LegacyChatRepositoryRef ref) {
  return LegacyChatRepository.withClient(ref.read(supabaseProvider));
}

ProviderJobGroup _groupFromStatus(String rawStatus, String uiGroup) {
  switch (rawStatus) {
    case 'accepted':
    case 'waiting_client':
      return ProviderJobGroup.waitingClient;
    case 'on_the_way':
    case 'in_progress':
    case 'execution_overdue':
    case 'dispute':
      return ProviderJobGroup.active;
    case 'completed':
    case 'refunded':
      return ProviderJobGroup.history;
    default:
      return uiGroup == 'active'
          ? ProviderJobGroup.active
          : uiGroup == 'history'
              ? ProviderJobGroup.history
              : ProviderJobGroup.waitingClient;
  }
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
AppJobRepository appJobRepository(AppJobRepositoryRef ref) {
  return AppJobRepository(client: ref.read(supabaseProvider));
}

/// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
@riverpod
Future<Map<String, dynamic>?> providerJobById(
    ProviderJobByIdRef ref, String jobId,) async {
  final repo = ref.read(appJobRepositoryProvider);
  return await repo.getProviderJobSmartById(jobId);
}

/// Lista de jobs públicos para home do prestador (v_provider_jobs_public)
@riverpod
Future<List<Map<String, dynamic>>> providerJobsPublic(
    ProviderJobsPublicRef ref,) async {
  final repo = ref.read(appJobRepositoryProvider);
  return await repo.getProviderJobsPublic();
}

/// Perfil completo do prestador (v_provider_me) - usado para main page, profile
@riverpod
Future<Map<String, dynamic>?> providerMeFull(ProviderMeFullRef ref) async {
  final repo = ref.read(providerRepositoryProvider);
  return await repo.getMe();
}

/// Perfil do prestador com ensureProfile (para account page)
@riverpod
Future<Map<String, dynamic>?> providerMeForAccount(
    ProviderMeForAccountRef ref) async {
  final repo = ref.read(providerRepositoryProvider);
  return await repo.getMeEnsured();
}

/// Dados do header do prestador (v_provider_me)
@riverpod
Future<Map<String, dynamic>?> providerMe(ProviderMeRef ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final me = await supabase.from('v_provider_me').select('''
    provider_id, full_name, city, status, rating, verification_status
  ''').maybeSingle();

  if (me == null) return null;
  return Map<String, dynamic>.from(me as Map);
}

/// Roles do usuário (client | provider | both | null)
@riverpod
Future<String?> providerMyRoles(ProviderMyRolesRef ref) async {
  final repo = ref.read(providerRepositoryProvider);
  return await repo.getMyRoles();
}

/// Lista de serviços de um prestador (v_public_provider_services)
@riverpod
Future<List<String>> providerServiceNames(
    ProviderServiceNamesRef ref, String? providerId) async {
  final repo = ref.read(providerRepositoryProvider);
  if (providerId != null && providerId.isNotEmpty) {
    return await repo.getServiceNamesByProviderId(providerId);
  }
  return await repo.getMyServiceNames();
}

/// Banners ativos (partner_banners) com URLs resolvidas
@riverpod
Future<List<Map<String, dynamic>>> providerBanners(
    ProviderBannersRef ref,) async {
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

/// Perfil do cliente para home (endereço, nome, cidade)
@riverpod
Future<Map<String, dynamic>?> clientMeForHome(ClientMeForHomeRef ref) async {
  final repo = ref.read(clientRepositoryProvider);
  return await repo.getProfileForHome();
}

/// Jobs recentes do cliente (status waiting_providers)
@riverpod
Future<List<Map<String, dynamic>>> clientRecentJobsWaiting(
    ClientRecentJobsWaitingRef ref,) async {
  final user = ref.watch(supabaseProvider).auth.currentUser;
  if (user == null) return [];
  final repo = ref.read(appJobRepositoryProvider);
  return await repo.getClientRecentJobsWaitingProviders(user.id);
}

/// Pedidos ativos do cliente (esperando profissionais + em andamento),
/// usando a mesma view v_client_my_jobs_dashboard e regras de prioridade
/// (jobs com novos candidatos primeiro).
@riverpod
Future<List<Map<String, dynamic>>> clientActiveJobs(
    ClientActiveJobsRef ref,) async {
  final supabase = ref.read(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final prefs = await ref.watch(sharedPreferencesProvider.future);

  // Busca jobs ainda em andamento (abertos / aguardando / em execução)
  final rows = await supabase
      .from('v_client_my_jobs_dashboard')
      .select('''
        job_id, title, description, status, created_at, job_code,
        quotes_count, new_candidates_count, dispute_status
      ''')
      // ignora disputas (essas já aparecem em outra seção da tela de pedidos)
      .not('dispute_status', 'in', '("open","resolved")')
      .not(
        'status',
        'in',
        '("completed","cancelled_by_client","cancelled_by_provider","cancelled","refunded")',
      )
      .order('created_at', ascending: false)
      .limit(30);

  final normalized = <Map<String, dynamic>>[];

  for (final row in rows as List<dynamic>) {
    final r = Map<String, dynamic>.from(row as Map);
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
    });
  }

  // Ordena priorizando pedidos aguardando profissionais com novos candidatos
  normalized.sort((a, b) {
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

  return normalized.take(10).toList();
}

/// Jobs que precisam de atenção do cliente na home:
/// - Jobs com novos candidatos (new_candidates_count > 0)
/// - Jobs finalizados que ainda não foram avaliados pelo cliente
@riverpod
Future<List<Map<String, dynamic>>> clientJobAlerts(
    ClientJobAlertsRef ref,) async {
  final supabase = ref.read(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final alerts = <Map<String, dynamic>>[];

  // 1) Jobs com novos candidatos (aguardando profissionais)
  final jobsWaiting = await supabase
      .from('v_client_my_jobs_dashboard')
      .select('job_id, title, job_code, status, new_candidates_count')
      .eq('status', 'waiting_providers')
      .order('created_at', ascending: false)
      .limit(10);

  for (final row in jobsWaiting as List) {
    final r = Map<String, dynamic>.from(row as Map);
    final jobId = r['job_id']?.toString() ?? '';
    final total = (r['new_candidates_count'] as num?)?.toInt() ?? 0;
    final seen = prefs.getInt('client_seen_candidates_$jobId') ?? 0;
    final delta = (total - seen).clamp(0, 999);

    if (delta > 0) {
      alerts.add({
        'type': 'new_candidates',
        'job_id': jobId,
        'job_code': r['job_code'] ?? '',
        'title': r['title'] ?? '',
        'count': delta,
      });
    }
  }

  // 2) Jobs finalizados sem avaliação do cliente (reviews.from_user = client)
  final completedJobs = await supabase
      .from('v_client_my_jobs_dashboard')
      .select('job_id, title, job_code, status')
      .eq('status', 'completed')
      .order('created_at', ascending: false)
      .limit(10);

  for (final row in completedJobs as List) {
    final r = Map<String, dynamic>.from(row as Map);
    final jobId = r['job_id']?.toString() ?? '';

    final reviewRes = await supabase
        .from('reviews')
        .select('id')
        .eq('job_id', jobId)
        .eq('from_user', user.id)
        .maybeSingle();

    if (reviewRes == null) {
      alerts.add({
        'type': 'needs_review',
        'job_id': jobId,
        'job_code': r['job_code'] ?? '',
        'title': r['title'] ?? '',
      });
    }
  }

  return alerts;
}

/// Profissionais em destaque (rating >= 4.5 e >= 3 jobs concluídos)
@riverpod
Future<List<Map<String, dynamic>>> featuredProviders(
    FeaturedProvidersRef ref,) async {
  final supabase = ref.read(supabaseProvider);
  final res = await supabase
      .from('v_provider_public_profile')
      .select('provider_id, name, avatar_url, rating, completed_jobs_count, city')
      .gte('rating', 4.5)
      .gte('completed_jobs_count', 3)
      .order('rating', ascending: false)
      .limit(6);
  return (res as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// Banners ativos (partner_banners) - compartilhado cliente/prestador
@riverpod
Future<List<Map<String, dynamic>>> clientBanners(
    ClientBannersRef ref,) async {
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
    ProviderMyJobsRef ref, int selectedDays,) async {
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

  // 1) Unread messages — filter by type at DB level (type is top-level column, not in JSONB)
  final Map<String, int> unreadByJobId = {};
  try {
    final notifRes = await supabase
        .from('notifications')
        .select('data')
        .eq('user_id', user.id)
        .eq('type', 'chat_message')
        .eq('read', false);

    for (final row in notifRes as List<dynamic>) {
      final data = row['data'];
      if (data is Map) {
        final jobId = data['job_id']?.toString();
        if (jobId != null) {
          unreadByJobId[jobId] = (unreadByJobId[jobId] ?? 0) + 1;
        }
      }
    }
  } catch (_) {}

  // 2) Jobs (v_provider_my_jobs)
  // Active jobs (accepted, on_the_way, in_progress, etc.) are always fetched;
  // historical jobs (completed, cancelled) respect the selectedDays filter.
  final jobsRes = await supabase
      .from('v_provider_my_jobs')
      .select('*')
      .or('created_at.gte.$sinceStr,status.in.(accepted,on_the_way,in_progress,execution_overdue,dispute,waiting_client)')
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
      serviceTitle: j['title']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      priceLabel: priceLabel,
      rawStatus: rawStatus,
      statusLabel: _mapStatusLabel(rawStatus),
      statusColor: _mapStatusColor(rawStatus),
      dateLabel: DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
      sortDate: createdAt,
      unreadMessages: unreadByJobId[jobId] ?? 0,
      group: _groupFromStatus(rawStatus, uiGroup),
      openAsDispute: false,
    ),);
  }

  // 3) Disputes (v_provider_disputes)
  final disputesRes = await supabase
      .from('v_provider_disputes')
      .select(
        'dispute_id, job_id, dispute_status, dispute_description, dispute_created_at',
      )
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
      jobCode: 'Reclamação',
      serviceTitle: '',
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
    ),);
  }

  // 4) Consolidate
  final all = [...jobCards, ...disputeCards];

  // 5) Categorize
  final cancelled = all
      .where((e) =>
          e.rawStatus == 'cancelled' ||
          e.rawStatus == 'cancelled_by_client' ||
          e.rawStatus == 'cancelled_by_provider',)
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
    ClientMyJobsRef ref, int selectedDays,) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Faça login novamente para ver seus pedidos.');
  }

  // ref.read evita rebuilds desnecessários do provider
  final prefs = await ref.read(sharedPreferencesProvider.future);
  final since =
      DateTime.now().toUtc().subtract(Duration(days: selectedDays));
  final sinceStr = since.toIso8601String();

  // Query única: jobs recentes OU com disputa (elimina o bug NOT IN + NULL
  // e reduz chamadas de rede de 2 para 1)
  final allRows = await supabase
      .from('v_client_my_jobs_dashboard')
      .select('''
        job_id, title, description, status, created_at, job_code,
        quotes_count, new_candidates_count, dispute_status,
        provider_name, scheduled_date, payment_status, service_type_name
      ''')
      .or('created_at.gte.$sinceStr,dispute_status.eq.open,dispute_status.eq.resolved')
      .order('created_at', ascending: false);

  // Deduplicação por job_id (um job pode satisfazer as duas condições do OR)
  final Map<String, Map<String, dynamic>> byId = {};
  for (final row in allRows as List<dynamic>) {
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
    ClientJobDetailsRef ref, String jobId,) async {
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
      'provider_name': (q['provider_name'] as String?)?.trim().isNotEmpty == true
          ? (q['provider_name'] as String).trim()
          : _friendlyProviderName(providerId),
      'provider_avatar_url': q['provider_avatar_url'],
      'provider_rating': q['provider_rating'],
      'created_at': q['created_at'],
      'quote_id': q['quote_id'],
      'approximate_price': q['approximate_price'],
      'quote_message': q['message'],
      'proposed_start_at': q['proposed_start_at'],
      'proposed_end_at': q['proposed_end_at'],
      'proposed_date': q['proposed_date'],
      'proposed_start_time': q['proposed_start_time'],
      'proposed_end_time': q['proposed_end_time'],
      'estimated_duration_minutes': q['estimated_duration_minutes'],
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
  final cache = ref.watch(cacheServiceProvider);
  final cacheKey = '${city ?? 'all'}_${status ?? 'all'}';

  final cached = await cache.getJobs(cacheKey);
  if (cached != null) {
    return cached.map((e) => Job.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  final jobs = await repository.getJobs(city: city, status: status);
  await cache.saveJobs(cacheKey, jobs.map((j) => j.toJson()).toList());
  return jobs;
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

/// Stats resumidos para home do prestador (hoje, mês, rating)
@riverpod
Future<Map<String, dynamic>> providerHomeStats(
    ProviderHomeStatsRef ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return {'todayJobs': 0, 'monthEarnings': 0.0, 'rating': 0.0};

  final me = await supabase
      .from('v_provider_me')
      .select('provider_id, rating')
      .maybeSingle();
  if (me == null) return {'todayJobs': 0, 'monthEarnings': 0.0, 'rating': 0.0};

  final providerId = me['provider_id']?.toString() ?? '';
  final rating = (me['rating'] as num?)?.toDouble() ?? 0.0;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
  final monthStart = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

  int todayJobs = 0;
  try {
    final todayRes = await supabase
        .from('job_candidates')
        .select('id')
        .eq('provider_id', providerId)
        .gte('created_at', todayStart);
    todayJobs = (todayRes as List).length;
  } catch (_) {}

  double monthEarnings = 0.0;
  try {
    final earningsRes = await supabase
        .from('v_provider_my_jobs')
        .select('amount_provider')
        .eq('status', 'completed')
        .gte('created_at', monthStart);
    for (final row in earningsRes as List) {
      final amt = (row['amount_provider'] as num?)?.toDouble() ?? 0;
      monthEarnings += amt;
    }
  } catch (_) {}

  return {
    'todayJobs': todayJobs,
    'monthEarnings': monthEarnings,
    'rating': rating,
  };
}

/// Categorias de serviço do prestador para filtro rápido
@riverpod
Future<List<Map<String, dynamic>>> providerMyCategories(
    ProviderMyCategoriesRef ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final me = await supabase
      .from('providers')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();
  if (me == null) return [];

  final providerId = me['id']?.toString() ?? '';

  final res = await supabase
      .from('provider_service_types')
      .select('service_type_id, service_types!inner(category_id, service_categories!inner(id, name))')
      .eq('provider_id', providerId);

  final seen = <String>{};
  final categories = <Map<String, dynamic>>[];
  for (final row in res as List) {
    final st = row['service_types'];
    if (st is Map) {
      final sc = st['service_categories'];
      if (sc is Map) {
        final id = sc['id']?.toString() ?? '';
        final name = sc['name']?.toString() ?? '';
        if (id.isNotEmpty && !seen.contains(id)) {
          seen.add(id);
          categories.add({'id': id, 'name': name});
        }
      }
    }
  }
  return categories;
}

@riverpod
class JobActions extends _$JobActions {
  @override
  FutureOr<void> build() async {}

  Future<Job?> create(Map<String, dynamic> jobData) async {
    state = const AsyncValue.loading();

    return await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      final cache = ref.read(cacheServiceProvider);
      final job = await repository.createJob(jobData);
      await cache.clearJobs();
      ref.invalidate(jobsListProvider);
      return job;
    }).then((result) => result.value);
  }

  Future<void> updateJob(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      final cache = ref.read(cacheServiceProvider);
      await repository.updateJob(id, updates);
      await cache.clearJobs();
      ref.invalidate(jobsListProvider);
      ref.invalidate(jobByIdProvider(id));
    });
  }
}
