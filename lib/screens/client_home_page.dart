// lib/screens/client_home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:renthus/core/providers/job_draft_provider.dart';
import 'package:renthus/core/services/job_draft_service.dart';
import 'package:renthus/core/providers/legacy_notification_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/core/providers/service_provider.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/screens/provider_public_profile_page.dart';
import 'package:renthus/widgets/service_card.dart';
import 'package:renthus/models/home_service.dart';
import 'package:renthus/screens/create_job_bottom_sheet.dart';

import 'package:renthus/screens/client_service_search_page.dart';
import 'package:renthus/screens/client_my_jobs_page.dart';

class ClientHomePage extends ConsumerStatefulWidget {
  const ClientHomePage({super.key});

  @override
  ConsumerState<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends ConsumerState<ClientHomePage> {
  static const roxo = Color(0xFF3B246B);
  static const laranja = Color(0xFFFF6600);

  // notificações (usa legacy repo)
  int _unreadCount = 0;

  // banners (estado local para PageController)
  List<_HomeBanner> _banners = [];
  late PageController _bannerController;
  Timer? _bannerTimer;
  static const int _kInitialBannerPage = 1000;
  int _currentBannerPage = _kInitialBannerPage;

  static const _kAlertHashKey = 'client_home_last_alert_hash';

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(
      viewportFraction: 0.92,
      initialPage: _kInitialBannerPage,
    );

    _loadUnreadCount();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // ---------------- CLIENTE ----------------

  static String _formatAddressLine(Map<String, dynamic>? res) {
    if (res == null) return 'Endereço não informado';
    final street = (res['address_street'] ?? '').toString();
    final number = (res['address_number'] ?? '').toString();
    if (street.isEmpty) return 'Endereço não informado';
    if (number.isEmpty) return street;
    return '$street, $number';
  }

  String _saudacaoHorario() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _primeiroNome(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '';
    final parts = fullName.trim().split(' ');
    return parts.first;
  }

  // ---------------- NOTIFICAÇÕES ----------------

  Future<void> _loadUnreadCount() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final notifRepo = ref.read(legacyNotificationRepositoryProvider);
      final count = await notifRepo.getUnreadCount(user.id);
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (e) {
      debugPrint('Erro ao carregar contagem de notificações (cliente): $e');
    }
  }

  Future<void> _openNotifications() async {
    await context.pushNotifications('client');
    _loadUnreadCount();
  }

  // ---------------- JOBS RECENTES ----------------

  void _openMyJobs() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ClientMyJobsPage(showBackButton: true),
      ),
    );
  }

  static List<_HomeBanner> _mapBanners(List<Map<String, dynamic>> rows) {
    return rows
        .map((r) => _HomeBanner(
              title: r['title'] ?? '',
              subtitle: r['subtitle'],
              imageUrl: r['imageUrl'] ?? '',
              actionType: r['actionType'],
              actionValue: r['actionValue'],
            ))
        .toList();
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();

    if (_banners.length <= 1) return;

    _bannerTimer = Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer) {
        if (!_bannerController.hasClients || _banners.isEmpty) return;

        final next = _currentBannerPage + 1;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        _currentBannerPage = next;
      },
    );
  }

  int _realBannerIndex(int virtualIndex, [List<_HomeBanner>? banners]) {
    final list = banners ?? _banners;
    if (list.isEmpty) return 0;
    return virtualIndex % list.length;
  }

  void _onBannerTap(_HomeBanner banner) {
    if (banner.actionType == 'open_service' &&
        banner.actionValue != null &&
        banner.actionValue!.isNotEmpty) {
      _openCreateJob(serviceSuggestion: banner.actionValue);
      return;
    }
    debugPrint(
        'Banner clicado: ${banner.title} / ${banner.actionType} (sem ação específica)',);
  }

  // ---------------- CRIAR NOVO PEDIDO (ajuste overflow) ----------------

  Future<void> _openCreateJob({String? serviceSuggestion}) async {
    final jobId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // sem Padding com viewInsets: o próprio bottom sheet cuida do teclado
        return CreateJobBottomSheet(
          initialServiceSuggestion: serviceSuggestion,
        );
      },
    );

    if (jobId != null && jobId.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido criado com sucesso!')),
      );
    }
  }

  // ---------------- SEARCH (usa tela com chips) ----------------

  Future<void> _openSearch() async {
    final suggestion = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ClientServiceSearchPage(
          showAllOnStart: false,
        ),
      ),
    );

    if (suggestion != null && suggestion.isNotEmpty) {
      _openCreateJob(serviceSuggestion: suggestion);
    }
  }

  // ---------------- SEGURANÇA ----------------

  void _openWhyPayInApp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WhyPayInAppPage(),
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final meAsync = ref.watch(clientMeForHomeProvider);
    final alertsAsync = ref.watch(clientJobAlertsProvider);
    final bannersAsync = ref.watch(clientBannersProvider);
    final servicesAsync = ref.watch(homeServicesProvider);
    final draftServiceAsync = ref.watch(jobDraftServiceProvider);
    final featuredAsync = ref.watch(featuredProvidersProvider);

    final alerts = alertsAsync.valueOrNull ?? [];
    final draftService = draftServiceAsync.valueOrNull;

    ref.listen(clientJobAlertsProvider, (prev, next) {
      if (next.hasValue && (next.value ?? []).isNotEmpty) {
        _checkAndShowAlerts(next.value!);
      }
    });

    final addressRes = meAsync.valueOrNull;
    final addressLine = meAsync.isLoading ? 'Carregando...' : _formatAddressLine(addressRes);
    final clientName = (addressRes?['full_name'] as String?)?.trim();
    final clientCity = (addressRes?['city'] as String?)?.trim();
    final loadingAddress = meAsync.isLoading;

    final featuredProviders = featuredAsync.valueOrNull ?? [];

    final bannersList = bannersAsync.valueOrNull ?? [];
    final displayBanners = bannersList.isNotEmpty
        ? _mapBanners(bannersList)
        : _banners;
    if (_banners.length != bannersList.length && bannersList.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _banners = _mapBanners(bannersList);
            _startBannerAutoScroll();
          });
        }
      });
    }
    final loadingBanners = bannersAsync.isLoading;

    final services = servicesAsync.valueOrNull ?? [];
    final loadingServices = servicesAsync.isLoading;
    final servicesError = servicesAsync.hasError ? servicesAsync.error?.toString() : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: roxo,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _openSearch,
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: const Row(
                              children: [
                                Icon(Icons.search,
                                    color: Colors.grey, size: 18,),
                                SizedBox(width: 6),
                                Text(
                                  'Buscar serviço (ex: eletricista)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _openNotifications,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.notifications_none,
                                color: Colors.white,
                                size: 18,
                              ),
                              if (_unreadCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      _unreadCount > 9
                                          ? '9+'
                                          : _unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          clientName == null || clientName.isEmpty
                              ? '${_saudacaoHorario()} 👋'
                              : '${_saudacaoHorario()}, ${_primeiroNome(clientName)} 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      // abrir tela de endereço no futuro
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            loadingAddress
                                ? 'Carregando endereço...'
                                : (addressLine.isEmpty ? 'Adicionar endereço' : addressLine),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientMeForHomeProvider);
          ref.invalidate(clientJobAlertsProvider);
          ref.invalidate(jobDraftServiceProvider);
          ref.invalidate(featuredProvidersProvider);
          ref.invalidate(clientBannersProvider);
          ref.invalidate(homeServicesProvider);
          await _loadUnreadCount();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding + 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _openWhyPayInApp,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6,),
                        decoration: BoxDecoration(
                          color: laranja,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: Colors.white, size: 16,),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Para sua segurança, pague sempre pelo app.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.white, size: 18,),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ALERTAS (chips horizontais)
                    _buildAlertChips(alerts),

                    // BANNERS
                    if (loadingBanners)
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          height: 130,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    else if (displayBanners.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(
                            height: 130,
                            child: PageView.builder(
                              controller: _bannerController,
                              onPageChanged: (virtualIndex) {
                                setState(() {
                                  _currentBannerPage = virtualIndex;
                                });
                              },
                              itemBuilder: (context, virtualIndex) {
                                if (displayBanners.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final index =
                                    _realBannerIndex(virtualIndex, displayBanners);
                                final banner = displayBanners[index];

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: GestureDetector(
                                    onTap: () => _onBannerTap(banner),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        banner.imageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                          if (progress == null) return child;
                                          return Container(
                                            color: Colors.grey.shade300,
                                          );
                                        },
                                        errorBuilder: (_, __, ___) {
                                          return Container(
                                            color: Colors.grey.shade300,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'Não foi possível carregar o banner.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(displayBanners.length, (index) {
                              final isActive =
                                  index == _realBannerIndex(_currentBannerPage, displayBanners);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                height: 4,
                                width: isActive ? 18 : 8,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? roxo
                                      : Colors.grey.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // CONTINUE DE ONDE PAROU (rascunhos)
                    if (draftService != null) _buildDraftsSection(draftService),

                    const SizedBox(height: 16),

                    const Text(
                      'Construção e Reforma',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: roxo,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            // GRID SERVIÇOS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildServicesSection(
                  loadingServices: loadingServices,
                  services: services,
                  servicesError: servicesError,
                ),
              ),
            ),

            // SEÇÕES FINAIS
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 14, 12, bottomPadding + 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PROFISSIONAIS EM DESTAQUE
                    if (featuredProviders.isNotEmpty)
                      _buildFeaturedProvidersSection(featuredProviders),

                    _buildTopServicesSection(
                      services: services,
                      clientCity: clientCity,
                    ),
                    const SizedBox(height: 20),
                    _buildHowItWorksSection(),
                    const SizedBox(height: 20),
                    const Text(
                      'Talvez você também precise de:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: roxo,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 85,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _InterestCard(
                            label: 'Montagem de móveis',
                            onTap: () => _openCreateJob(
                              serviceSuggestion: 'Montagem de móveis',
                            ),
                          ),
                          _InterestCard(
                            label: 'Fretes e mudanças',
                            onTap: () => _openCreateJob(
                              serviceSuggestion: 'Fretes e mudanças',
                            ),
                          ),
                          _InterestCard(
                            label: 'Pintura residencial',
                            onTap: () => _openCreateJob(
                              serviceSuggestion: 'Pintura residencial',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- SEÇÕES AUXILIARES ----------

  /// Gera hash string dos alertas atuais
  String _alertsHash(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) return '';
    final parts = alerts.map((a) => '${a['type']}:${a['job_id']}').toList()
      ..sort();
    return parts.join(',');
  }

  /// Verifica se tem alertas novos que o cliente ainda não viu
  Future<bool> _hasUnseenAlerts(List<Map<String, dynamic>> alerts) async {
    if (alerts.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastHash = prefs.getString(_kAlertHashKey) ?? '';
    final currentHash = _alertsHash(alerts);
    return currentHash != lastHash;
  }

  /// Marca os alertas atuais como vistos
  Future<void> _markAlertsSeen(List<Map<String, dynamic>> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAlertHashKey, _alertsHash(alerts));
  }

  Future<void> _checkAndShowAlerts(List<Map<String, dynamic>> alerts) async {
    final shouldShow = await _hasUnseenAlerts(alerts);
    if (!shouldShow || !mounted) return;

    // Marcar como visto ANTES de mostrar (evita mostrar 2x se rebuild rápido)
    await _markAlertsSeen(alerts);

    if (!mounted) return;
    _showAlertsDialog(alerts);
  }

  void _showAlertsDialog(List<Map<String, dynamic>> alerts) {
    final parentContext = context;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar alertas',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, anim, secondAnim) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _AlertsDialog(
              alerts: alerts,
              onTapAlert: (alert) {
                Navigator.of(parentContext).pop();
                final jobId = alert['job_id']?.toString() ?? '';
                if (jobId.isNotEmpty && parentContext.mounted) {
                  parentContext.pushClientJobDetails(jobId);
                }
              },
              onClose: () => Navigator.of(parentContext).pop(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertChips(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Atenção',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: roxo,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openMyJobs,
                child: const Text(
                  'Ver todos →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: roxo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final alert = alerts[index];
                final type = alert['type'] as String;

                IconData icon;
                Color bgColor;
                String label;

                if (type == 'new_candidates') {
                  icon = Icons.person_add_rounded;
                  bgColor = const Color(0xFF0DAA00);
                  final count = alert['count'] ?? 0;
                  label = '$count novo(s)\ncandidato(s)';
                } else {
                  icon = Icons.check_circle_rounded;
                  bgColor = laranja;
                  label = 'Confirmar\ne avaliar';
                }

                return GestureDetector(
                  onTap: () {
                    final jobId = alert['job_id']?.toString() ?? '';
                    if (jobId.isNotEmpty) {
                      context.pushClientJobDetails(jobId);
                    }
                  },
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bgColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bgColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: bgColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: bgColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsSection(JobDraftService draftService) {
    final drafts = draftService.getDrafts();
    if (drafts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Continue de onde parou',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: roxo,
          ),
        ),
        const SizedBox(height: 8),
        ...drafts.map((draft) {
          final serviceName = draft['service_name'] ?? 'Serviço';
          final description = draft['description'] ?? '';
          final savedAt = DateTime.tryParse(draft['saved_at'] ?? '');
          final timeAgo = savedAt != null ? _formatTimeAgo(savedAt) : '';
          final draftId = draft['draft_id']?.toString() ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: Key(draftId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              onDismissed: (_) async {
                await draftService.removeDraft(draftId);
                if (mounted) setState(() {});
              },
                child: InkWell(
                onTap: () => _openCreateJobFromDraft(draft, draftService),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.build_outlined, size: 20, color: roxo),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceName.isNotEmpty ? serviceName : 'Pedido incompleto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              description.isNotEmpty
                                  ? description
                                  : 'Pedido não finalizado',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (timeAgo.isNotEmpty)
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black38,
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.black38),
                        onPressed: () async {
                          await draftService.removeDraft(draftId);
                          if (mounted) setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (drafts.length > 1)
          Center(
            child: TextButton(
              onPressed: () async {
                await draftService.clearAll();
                if (mounted) setState(() {});
              },
              child: const Text(
                'Limpar todos',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'há 1 dia';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    return 'há ${(diff.inDays / 7).floor()} sem';
  }

  Future<void> _openCreateJobFromDraft(
    Map<String, dynamic> draft,
    JobDraftService draftService,
  ) async {
    await draftService.removeDraft(draft['draft_id']?.toString() ?? '');

    if (!mounted) return;

    final jobId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateJobBottomSheet(restoreDraft: draft),
    );

    if (jobId != null && jobId.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido criado com sucesso!')),
      );
    }

    if (mounted) setState(() {});
  }

  Widget _buildFeaturedProvidersSection(
    List<Map<String, dynamic>> providers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profissionais em destaque ⭐',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: roxo,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final p = providers[index];
              final name = (p['name'] as String?) ?? 'Profissional';
              final avatarUrl = p['avatar_url'] as String?;
              final rating = (p['rating'] as num?)?.toDouble();
              final city = (p['city'] as String?) ?? '';
              final completedJobs =
                  (p['completed_jobs_count'] as num?)?.toInt() ?? 0;
              final initials =
                  name.isNotEmpty ? name[0].toUpperCase() : 'P';

              return GestureDetector(
                onTap: () {
                  final pid = p['provider_id']?.toString() ?? '';
                  if (pid.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProviderPublicProfilePage(providerId: pid),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFEDE7F6),
                        backgroundImage:
                            (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? NetworkImage(avatarUrl)
                                : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: roxo,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 2),
                          Text(
                            rating != null
                                ? rating.toStringAsFixed(1)
                                : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$completedJobs serv.',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildServicesSection({
    required bool loadingServices,
    required List<HomeService> services,
    required String? servicesError,
  }) {
    if (loadingServices) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            return const _ShimmerServiceCard();
          },
        ),
      );
    }

    if (servicesError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Não foi possível carregar os serviços.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              servicesError,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(homeServicesProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text(
                'Tentar novamente',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhum serviço configurado ainda.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final visible = services
        .where(
          (s) =>
              (s.thumbUrl != null && s.thumbUrl!.isNotEmpty) ||
              (s.imageUrl != null && s.imageUrl!.isNotEmpty),
        )
        .toList();

    final limited = visible.take(6).toList();

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: limited.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            final service = limited[index];
            final subtitle = _buildServiceSubtitle(service);

            return GestureDetector(
              onTap: () => _openCreateJob(
                serviceSuggestion: service.serviceKeyword ?? service.title,
              ),
              child: ServiceCard(
                title: service.title,
                subtitle: subtitle,
                imageUrl: service.thumbUrl ?? service.imageUrl ?? '',
                thumbUrl: service.thumbUrl,
              ),
            );
          },
        ),
        if (visible.length > 6)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final suggestion = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const ClientServiceSearchPage(
                      showAllOnStart: true,
                    ),
                  ),
                );
                if (suggestion != null && suggestion.isNotEmpty) {
                  _openCreateJob(serviceSuggestion: suggestion);
                }
              },
              child: const Text(
                'Ver todos os serviços',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _buildServiceSubtitle(HomeService service) {
    final base = service.subtitle?.trim();
    if (base != null && base.isNotEmpty) return base;

    final t = service.title.toLowerCase();
    if (t.contains('pedreiro')) {
      return 'Obra, reforma ou pequenos reparos com pedreiro perto de você.';
    }
    if (t.contains('solda') || t.contains('soldador')) {
      return 'Serviços de solda com segurança para sua casa ou empresa.';
    }
    if (t.contains('ar cond') || t.contains('ar-cond') || t.contains('ar ')) {
      return 'Instalação e manutenção de ar-condicionado com profissional qualificado.';
    }
    if (t.contains('calheiro')) {
      return 'Instalação e manutenção de calhas para evitar infiltrações.';
    }

    return '${service.title} com prestadores avaliados perto de você.';
  }

  Widget _buildTopServicesSection({
    required List<HomeService> services,
    required String? clientCity,
  }) {
    if (services.isEmpty) return const SizedBox.shrink();

    final visible = services
        .where(
          (s) =>
              (s.thumbUrl != null && s.thumbUrl!.isNotEmpty) ||
              (s.imageUrl != null && s.imageUrl!.isNotEmpty),
        )
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    final top3 = visible.take(3).toList();
    final city = clientCity ?? 'sua região';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Serviços mais pedidos em $city',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: roxo,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: top3.length,
            itemBuilder: (context, index) {
              final service = top3[index];
              return GestureDetector(
                onTap: () => _openCreateJob(
                  serviceSuggestion: service.serviceKeyword ?? service.title,
                ),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: laranja,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          service.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Como funciona o Renthus',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: roxo,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _HowItWorksStep(
              icon: Icons.edit_note_outlined,
              title: '1. Faça seu pedido',
              subtitle:
                  'Descreva o serviço, envie fotos e escolha a melhor data.',
            ),
            SizedBox(width: 8),
            _HowItWorksStep(
              icon: Icons.handshake_outlined,
              title: '2. Escolha o prestador',
              subtitle: 'Compare avaliações, preços e escolha com segurança.',
            ),
            SizedBox(width: 8),
            _HowItWorksStep(
              icon: Icons.verified_outlined,
              title: '3. Pague pelo app',
              subtitle:
                  'Seu dinheiro fica protegido até o serviço ser concluído.',
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------- WIDGETS AUXILIARES ----------------

class _AlertsDialog extends StatelessWidget {
  const _AlertsDialog({
    required this.alerts,
    required this.onTapAlert,
    required this.onClose,
  });

  final List<Map<String, dynamic>> alerts;
  final void Function(Map<String, dynamic>) onTapAlert;
  final VoidCallback onClose;

  static const roxo = Color(0xFF3B246B);
  static const laranja = Color(0xFFFF6600);
  static const verde = Color(0xFF0DAA00);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.88,
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.65,
        minHeight: screenHeight * 0.3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: roxo.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  alerts.length == 1
                      ? 'Novidade no seu pedido!'
                      : 'Novidades nos seus pedidos!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: roxo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${alerts.length} ${alerts.length == 1 ? 'ação pendente' : 'ações pendentes'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),

          // LISTA DE ALERTAS
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final alert = alerts[index];
                final type = alert['type'] as String;
                final title = alert['title'] ?? 'Serviço';
                final code = alert['job_code'] ?? '';

                final isCandidate = type == 'new_candidates';
                final accentColor = isCandidate ? verde : laranja;

                return InkWell(
                  onTap: () => onTapAlert(alert),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accentColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        // Ícone
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isCandidate
                                ? Icons.person_add_rounded
                                : Icons.check_circle_rounded,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (code.isNotEmpty)
                                Text('#$code',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black45)),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCandidate
                                    ? '${alert['count']} novo(s) candidato(s)!'
                                    : 'Confirme e avalie o serviço',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: accentColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        // Seta
                        Icon(Icons.chevron_right,
                            color: accentColor.withOpacity(0.5), size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // BOTÃO FECHAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Fechar',
                    style: TextStyle(color: Colors.black54, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {

  const _HowItWorksStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: _ClientHomePageState.laranja),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestCard extends StatelessWidget {

  const _InterestCard({
    required this.label,
    required this.onTap,
  });
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ShimmerServiceCard extends StatelessWidget {
  const _ShimmerServiceCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              height: 12,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBanner {

  _HomeBanner({
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.actionType,
    this.actionValue,
  });
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? actionType;
  final String? actionValue;
}

// ---------------- TELA: POR QUE PAGAR PELO APP ----------------

class WhyPayInAppPage extends StatelessWidget {
  const WhyPayInAppPage({super.key});

  static const roxo = Color(0xFF3B246B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Por que pagar pelo app?',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: roxo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Sua segurança em primeiro lugar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: roxo,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Quando você paga pelo Renthus, o valor fica protegido até que o prestador conclua o serviço conforme combinado.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '🔒 O prestador só recebe depois de realizar o serviço',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'O pagamento é liberado para o prestador somente após a conclusão do serviço, deixando você mais tranquilo na hora de contratar.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '⏱ Você tem até 24 horas para reclamar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Se o serviço não foi realizado como combinado, você pode abrir uma reclamação pelo app em até 24 horas após a conclusão.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '💸 Possibilidade de receber seu dinheiro de volta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Caso a sua reclamação seja procedente, o valor pode ser estornado e você não fica no prejuízo.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Assim, você contrata com mais segurança e o prestador também trabalha com mais responsabilidade. Todo mundo ganha.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
