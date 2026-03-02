import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/notification_badge_provider.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/screens/partner_stores_page.dart';
import 'package:renthus/screens/provider_verification_page.dart';
import 'package:renthus/widgets/verification_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProviderHomePage extends ConsumerStatefulWidget {
  const ProviderHomePage({super.key});

  @override
  ConsumerState<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends ConsumerState<ProviderHomePage> {
  static const _roxo = Color(0xFF3B246B);
  static const _laranja = Color(0xFFFF6600);
  static const _verde = Color(0xFF0DAA00);

  final PageController _bannerController =
      PageController(viewportFraction: 0.92);
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  String? _selectedCategoryId;
  bool _popupChecked = false;

  final _jobsListKey = GlobalKey();

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll(List<Map<String, dynamic>> banners) {
    _bannerTimer?.cancel();
    if (banners.length <= 1) return;

    _bannerTimer = Timer.periodic(
      const Duration(seconds: 4),
      (Timer timer) {
        if (!_bannerController.hasClients || banners.isEmpty) return;

        int next = _currentBannerPage + 1;
        if (next >= banners.length) next = 0;

        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );

        setState(() => _currentBannerPage = next);
      },
    );
  }

  String _formatAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
      if (diff.inHours < 24) return '${diff.inHours} h atrás';
      return '${diff.inDays} d atrás';
    } catch (_) {
      return '';
    }
  }

  int _minutesAgo(String? iso) {
    if (iso == null) return 999;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateTime.now().difference(dt).inMinutes;
    } catch (_) {
      return 999;
    }
  }

  String? _firstThumbFromPhotos(dynamic photosJson) {
    try {
      if (photosJson == null) return null;
      if (photosJson is List && photosJson.isNotEmpty) {
        final first = photosJson.first;
        if (first is Map) {
          final m = Map<String, dynamic>.from(first);
          final t = m['thumb_url']?.toString().trim();
          final u = m['url']?.toString().trim();
          if (t != null && t.isNotEmpty) return t;
          if (u != null && u.isNotEmpty) return u;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _reloadAll() async {
    ref.invalidate(providerMeProvider);
    ref.invalidate(providerJobsPublicProvider);
    ref.invalidate(providerBannersProvider);
    ref.invalidate(providerHomeUnreadCountProvider);
    ref.invalidate(providerHomeStatsProvider);
    ref.invalidate(providerMyCategoriesProvider);
  }

  Future<void> _showVerificationPopupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('verification_popup_shown_v1') == true) return;
    if (!mounted) return;

    await prefs.setBool('verification_popup_shown_v1', true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _roxo.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_outlined,
                  size: 40, color: _roxo),
            ),
            const SizedBox(height: 16),
            const Text(
              'Falta pouco para começar!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Para receber pedidos e pagamentos, precisamos verificar '
              'seus documentos e dados bancários.\n\nLeva menos de 5 minutos.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Depois', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ProviderVerificationPage(),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _roxo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Completar agora'),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildVerificationBanner(String verificationStatus) {
    return SliverToBoxAdapter(
      child: VerificationBanner(
        verificationStatus: verificationStatus,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ProviderVerificationPage(),
          ));
        },
      ),
    );
  }

  void _scrollToJobs() {
    final ctx = _jobsListKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(providerMeProvider);
    final jobsAsync = ref.watch(providerJobsPublicProvider);
    final bannersAsync = ref.watch(providerBannersProvider);
    final unreadCount = ref.watch(notificationBadgeControllerProvider).totalCount;
    final statsAsync = ref.watch(providerHomeStatsProvider);
    final categoriesAsync = ref.watch(providerMyCategoriesProvider);

    final loadingHeader = meAsync.isLoading;
    String providerName = 'Olá, prestador';
    String locationLabel = 'Localização não informada';
    bool isVerified = false;

    String verificationStatus = 'pending';

    meAsync.whenData((me) {
      if (me == null) {
        providerName = ref.watch(currentUserProvider) == null
            ? 'Faça login'
            : 'Olá, prestador';
        locationLabel = ref.watch(currentUserProvider) == null
            ? '—'
            : 'Cadastro em andamento';
      } else {
        final fullName = (me['full_name'] as String?)?.trim();
        final city = (me['city'] as String?)?.trim();
        final status = (me['status'] as String?)?.trim();
        verificationStatus =
            (me['verification_status'] as String?)?.trim() ?? 'pending';
        isVerified = (me['verification_status'] as String?) == 'active';
        providerName =
            'Olá, ${fullName?.isNotEmpty == true ? fullName : 'prestador'}';
        locationLabel = (city != null && city.isNotEmpty)
            ? city
            : 'Localização não informada';
        if (status != null && status.isNotEmpty && status != 'approved') {
          if (status == 'pending') {
            locationLabel = '$locationLabel • Em análise';
          }
          if (status == 'blocked') {
            locationLabel = '$locationLabel • Conta bloqueada';
          }
        }

        if (verificationStatus == 'pending' && !_popupChecked) {
          _popupChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showVerificationPopupIfNeeded();
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: RefreshIndicator(
        onRefresh: _reloadAll,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(
              loadingHeader: loadingHeader,
              providerName: providerName,
              locationLabel: locationLabel,
              isVerified: isVerified,
              unreadCount: unreadCount,
            ),
            _buildVerificationBanner(verificationStatus),
            _buildStatsRow(statsAsync),
            _buildNewOrdersUrgencyCard(jobsAsync),
            _buildHeaderAndStaticCards(
              loadingHeader: loadingHeader,
              locationLabel: locationLabel,
              bannersAsync: bannersAsync,
              jobsAsync: jobsAsync,
            ),
            _buildCategoryFilter(categoriesAsync),
            _buildJobsList(jobsAsync),
          ],
        ),
      ),
    );
  }

  // ──────────── APP BAR ────────────
  SliverAppBar _buildAppBar({
    required bool loadingHeader,
    required String providerName,
    required String locationLabel,
    required bool isVerified,
    required int unreadCount,
  }) {
    return SliverAppBar(
      backgroundColor: _roxo,
      pinned: true,
      elevation: 2,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loadingHeader ? 'Carregando...' : providerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVerified)
                const Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Icon(
                    Icons.verified,
                    color: Colors.lightBlueAccent,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  loadingHeader ? 'Carregando...' : locationLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
              backgroundColor: Colors.red,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
            onPressed: () async {
              await context.pushNotifications('provider');
              NotificationBadgeController.instance.loadFromDatabase();
            },
          ),
        ),
      ],
    );
  }

  // ──────────── 8.3 STATS ROW ────────────
  SliverToBoxAdapter _buildStatsRow(
      AsyncValue<Map<String, dynamic>> statsAsync) {
    return SliverToBoxAdapter(
      child: statsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (stats) {
          final todayJobs = (stats['todayJobs'] as int?) ?? 0;
          final monthEarnings = (stats['monthEarnings'] as num?)?.toDouble() ?? 0;
          final rating = (stats['rating'] as num?)?.toDouble() ?? 0;
          final currFmt =
              NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _miniStatCard(
                    icon: Icons.task_alt_rounded,
                    iconColor: _verde,
                    value: '$todayJobs',
                    label: 'Hoje',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStatCard(
                    icon: Icons.trending_up_rounded,
                    iconColor: _laranja,
                    value: currFmt.format(monthEarnings),
                    label: 'Este mês',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStatCard(
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber.shade700,
                    value: rating > 0 ? rating.toStringAsFixed(1) : '-',
                    label: 'Avaliação',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ──────────── 8.1 NEW ORDERS URGENCY CARD ────────────
  SliverToBoxAdapter _buildNewOrdersUrgencyCard(
      AsyncValue<List<Map<String, dynamic>>> jobsAsync) {
    final jobs = jobsAsync.valueOrNull ?? [];
    if (jobs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: _scrollToJobs,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _laranja.withOpacity(0.7), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _laranja.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _laranja.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${jobs.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _laranja,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${jobs.length} ${jobs.length == 1 ? 'novo pedido' : 'novos pedidos'} na sua região!',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Responda rápido para garantir o serviço',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _laranja),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────── HEADER + BANNERS ────────────
  SliverToBoxAdapter _buildHeaderAndStaticCards({
    required bool loadingHeader,
    required String locationLabel,
    required AsyncValue<List<Map<String, dynamic>>> bannersAsync,
    required AsyncValue<List<Map<String, dynamic>>> jobsAsync,
  }) {
    final banners = bannersAsync.valueOrNull ?? [];
    if (banners.isNotEmpty && _bannerTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startBannerAutoScroll(banners);
      });
    }
    final jobsCount = jobsAsync.valueOrNull?.length ?? 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _roxo.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.handshake,
                      color: _roxo,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Área de atendimento',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loadingHeader ? 'Carregando...' : locationLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PartnerStoresPage(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: _laranja.withOpacity(0.7),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _laranja.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: _laranja,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lojas parceiras Renthus',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _roxo,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Conheça parceiros com descontos e benefícios para seus serviços.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: _roxo),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            bannersAsync.when(
              loading: () => const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(height: 0),
              data: (list) {
                if (list.isEmpty) return const SizedBox(height: 0);
                return SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: _bannerController,
                    itemCount: list.length,
                    onPageChanged: (i) =>
                        setState(() => _currentBannerPage = i),
                    itemBuilder: (context, index) {
                      final banner = list[index];
                      final imageUrl = (banner['imageUrl'] as String?) ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            debugPrint(
                                "Banner clicado: ${banner['title'] ?? ''}");
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Novos serviços ($jobsCount)',
                  key: _jobsListKey,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Puxe pra baixo pra atualizar',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // ──────────── 8.2 CATEGORY FILTER CHIPS ────────────
  SliverToBoxAdapter _buildCategoryFilter(
      AsyncValue<List<Map<String, dynamic>>> categoriesAsync) {
    final categories = categoriesAsync.valueOrNull ?? [];
    if (categories.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final isAll = index == 0;
            final isSelected = isAll
                ? _selectedCategoryId == null
                : _selectedCategoryId == categories[index - 1]['id'];
            final label =
                isAll ? 'Todos' : (categories[index - 1]['name'] as String);

            return FilterChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategoryId = isAll ? null : categories[index - 1]['id'] as String;
                });
              },
              selectedColor: _roxo,
              backgroundColor: Colors.grey.shade200,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide.none,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          },
        ),
      ),
    );
  }

  // ──────────── JOBS LIST ────────────
  Widget _buildJobsList(AsyncValue<List<Map<String, dynamic>>> jobsAsync) {
    return jobsAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            ErrorHandler.friendlyErrorMessage(e),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
      ),
      data: (jobs) {
        final filtered = _selectedCategoryId == null
            ? jobs
            : jobs
                .where((j) =>
                    j['category_id']?.toString() == _selectedCategoryId)
                .toList();

        if (filtered.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _selectedCategoryId != null
                      ? 'Nenhum serviço nesta categoria no momento.'
                      : 'Ainda não há novos serviços para você.\nVolte em alguns minutos.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final job = filtered[index];
              final title =
                  (job['title'] as String?) ?? 'Serviço disponível';
              final desc =
                  (job['description'] as String?) ?? 'Sem descrição.';
              final city = (job['city'] as String?)?.trim() ?? '';
              final uf = (job['state'] as String?)?.trim() ?? '';
              final createdAt = job['created_at']?.toString();
              final thumbUrl = _firstThumbFromPhotos(job['photos']);
              final mins = _minutesAgo(createdAt);

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  index == 0 ? 8 : 4,
                  16,
                  index == filtered.length - 1 ? 16 : 4,
                ),
                child: _JobPublicCard(
                  title: title,
                  description: desc,
                  location:
                      [city, uf].where((e) => e.isNotEmpty).join(' - '),
                  ago: _formatAgo(createdAt),
                  thumbUrl: thumbUrl,
                  isNew: mins < 30,
                  onDetails: () => _openJobDetails(job),
                ),
              );
            },
            childCount: filtered.length,
          ),
        );
      },
    );
  }

  void _openJobDetails(Map<String, dynamic> job) {
    final id = job['id'];
    if (id == null) return;

    context.pushJobDetails(id.toString()).then((_) {
      ref.invalidate(providerJobsPublicProvider);
    });
  }
}

// ──────────── JOB CARD ────────────

class _JobPublicCard extends StatelessWidget {
  const _JobPublicCard({
    required this.title,
    required this.description,
    required this.location,
    required this.ago,
    this.thumbUrl,
    this.onDetails,
    this.isNew = false,
  });

  final String title;
  final String description;
  final String location;
  final String ago;
  final String? thumbUrl;
  final VoidCallback? onDetails;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF0DAA00);
    const Color roxo = Color(0xFF3B246B);
    const Color laranja = Color(0xFFFF6600);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: verde.withOpacity(0.6),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onDetails,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: verde.withOpacity(0.08),
                    child: (thumbUrl == null || thumbUrl!.isEmpty)
                        ? const Icon(Icons.photo, color: verde)
                        : Image.network(
                            thumbUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image, color: verde),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isNew) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: laranja,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NOVO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 12, color: verde),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location.isEmpty ? '—' : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: verde,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.access_time,
                              size: 11, color: Colors.black45),
                          const SizedBox(width: 2),
                          Text(
                            ago,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: onDetails,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Ver detalhes',
                              style: TextStyle(
                                fontSize: 11,
                                color: roxo,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
