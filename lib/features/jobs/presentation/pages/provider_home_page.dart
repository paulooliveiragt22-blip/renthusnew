import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/features/jobs/presentation/pages/job_details_page.dart';
import 'package:renthus/features/notifications/presentation/pages/notifications_page.dart';
import 'package:renthus/screens/partner_stores_page.dart';

class ProviderHomePage extends ConsumerStatefulWidget {
  const ProviderHomePage({super.key});

  @override
  ConsumerState<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends ConsumerState<ProviderHomePage> {
  static const _roxo = Color(0xFF3B246B);

  final PageController _bannerController =
      PageController(viewportFraction: 0.92);
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 't' || s == 'yes' || s == 'y';
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
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(providerMeProvider);
    final jobsAsync = ref.watch(providerJobsPublicProvider);
    final bannersAsync = ref.watch(providerBannersProvider);
    final unreadCount = ref.watch(providerHomeUnreadCountProvider);

    final loadingHeader = meAsync.isLoading;
    String providerName = 'Olá, prestador';
    String locationLabel = 'Localização não informada';
    bool isVerified = false;

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
        isVerified = _asBool(me['is_verified']) ||
            _asBool(me['documents_verified']) ||
            _asBool(me['verified']);
        providerName =
            'Olá, ${fullName?.isNotEmpty == true ? fullName : 'prestador'}';
        locationLabel = (city != null && city.isNotEmpty)
            ? city
            : 'Localização não informada';
        if (status != null && status.isNotEmpty && status != 'approved') {
          if (status == 'pending') locationLabel = '$locationLabel • Em análise';
          if (status == 'blocked') locationLabel = '$locationLabel • Conta bloqueada';
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
            _buildHeaderAndStaticCards(
              loadingHeader: loadingHeader,
              locationLabel: locationLabel,
              bannersAsync: bannersAsync,
              jobsAsync: jobsAsync,
            ),
            _buildJobsList(jobsAsync),
          ],
        ),
      ),
    );
  }

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
              const Icon(
                Icons.location_on,
                size: 14,
                color: Colors.white70,
              ),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await context.pushNotifications('provider');
                  ref.invalidate(providerHomeUnreadCountProvider);
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

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
                    color: const Color(0xFFFF6600).withOpacity(0.7),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6600).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: Color(0xFFFF6600),
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
                    const Icon(
                      Icons.chevron_right,
                      color: _roxo,
                    ),
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
                    onPageChanged: (i) => setState(() => _currentBannerPage = i),
                    itemBuilder: (context, index) {
                      final banner = list[index];
                      final imageUrl =
                          (banner['imageUrl'] as String?) ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            debugPrint(
                                "Banner clicado: ${banner['title'] ?? ''}",);
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

  Widget _buildJobsList(
      AsyncValue<List<Map<String, dynamic>>> jobsAsync,) {
    return jobsAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Erro ao carregar: $e',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Ainda não há novos serviços para você.\nVolte em alguns minutos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final job = jobs[index];
              final title =
                  (job['title'] as String?) ?? 'Serviço disponível';
              final desc =
                  (job['description'] as String?) ?? 'Sem descrição.';
              final city = (job['city'] as String?)?.trim() ?? '';
              final uf = (job['state'] as String?)?.trim() ?? '';
              final createdAt = job['created_at']?.toString();
              final thumbUrl = _firstThumbFromPhotos(job['photos']);

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  index == 0 ? 0 : 4,
                  16,
                  index == jobs.length - 1 ? 16 : 4,
                ),
                child: _JobPublicCard(
                  title: title,
                  description: desc,
                  location: [city, uf].where((e) => e.isNotEmpty).join(' - '),
                  ago: _formatAgo(createdAt),
                  thumbUrl: thumbUrl,
                  onDetails: () => _openJobDetails(job),
                ),
              );
            },
            childCount: jobs.length,
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

class _JobPublicCard extends StatelessWidget {

  const _JobPublicCard({
    required this.title,
    required this.description,
    required this.location,
    required this.ago,
    this.thumbUrl,
    this.onDetails,
  });
  final String title;
  final String description;
  final String location;
  final String ago;
  final String? thumbUrl;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF0DAA00);
    const Color roxo = Color(0xFF3B246B);

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
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
                          const Icon(Icons.location_on, size: 12, color: verde),
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
                          const SizedBox(width: 8),
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
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
