import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'job_details_page.dart';
import 'notifications_page.dart';
import 'partner_stores_page.dart';
import '../repositories/notification_repository.dart';

class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key});

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  final _supabase = Supabase.instance.client;
  final _notificationRepo = NotificationRepository();

  static const _roxo = Color(0xFF3B246B);

  // HEADER ------------------------
  bool _loadingHeader = true;
  String _providerName = 'Olá, prestador';
  String _locationLabel = 'Localização não informada';
  bool _isVerified = false;

  // JOBS NOVOS (SOMENTE VIEW) ----
  bool _loadingJobs = true;
  List<Map<String, dynamic>> _jobs = [];
  int _newJobsCount = 0;

  // NOTIFICAÇÕES ------------------
  int _unreadNotifications = 0;

  // BANNERS -----------------------
  bool _loadingBanners = true;
  List<_HomeBanner> _banners = [];
  final PageController _bannerController =
      PageController(viewportFraction: 0.92);
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _loadProviderHeader(); // ✅ agora lê a view v_provider_me
    await Future.wait([
      _loadJobsFromView(),
      _loadBanners(),
      _loadUnreadNotifications(),
    ]);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // ----------------- HEADER (VIEW: v_provider_me) -----------------

  bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 't' || s == 'yes' || s == 'y';
  }

  Future<void> _loadProviderHeader() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loadingHeader = false;
        _providerName = 'Faça login';
        _locationLabel = '—';
        _isVerified = false;
      });
      return;
    }

    try {
      setState(() => _loadingHeader = true);

      // ✅ Lê SOMENTE a view v_provider_me (nada de providers cru)
      final me = await _supabase.from('v_provider_me').select('''
            full_name,
            city,
            is_verified,
            documents_verified,
            verified,
            status
          ''').maybeSingle();

      if (!mounted) return;

      if (me == null) {
        // Não existe provider vinculado ao user ainda
        setState(() {
          _loadingHeader = false;
          _providerName = 'Olá, prestador';
          _locationLabel = 'Cadastro em andamento';
          _isVerified = false;
        });
        return;
      }

      final m = Map<String, dynamic>.from(me as Map);

      final fullName = (m['full_name'] as String?)?.trim();
      final city = (m['city'] as String?)?.trim();
      final status = (m['status'] as String?)?.trim();

      final isVerified = _asBool(m['is_verified']) ||
          _asBool(m['documents_verified']) ||
          _asBool(m['verified']);

      // Label de localização: só cidade (MVP por cidade)
      String location = 'Localização não informada';
      if (city != null && city.isNotEmpty) location = city;

      // Se o status não for approved, dá um feedback leve no header (sem travar home)
      if (status != null && status.isNotEmpty && status != 'approved') {
        // Ex.: pending / blocked / etc.
        // Você pode customizar as mensagens depois
        if (status == 'pending') location = '$location • Em análise';
        if (status == 'blocked') location = '$location • Conta bloqueada';
      }

      setState(() {
        _loadingHeader = false;
        _providerName =
            'Olá, ${fullName?.isNotEmpty == true ? fullName : 'prestador'}';
        _locationLabel = location;
        _isVerified = isVerified;
      });
    } catch (e) {
      debugPrint('Erro ao carregar header (v_provider_me): $e');
      if (!mounted) return;
      setState(() {
        _loadingHeader = false;
        _providerName = 'Olá, prestador';
        _locationLabel = '—';
        _isVerified = false;
      });
    }
  }

  // ------------------ NOTIFICAÇÕES -----------------------

  Future<void> _loadUnreadNotifications() async {
    try {
      final count = await _notificationRepo.fetchUnreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = count);
    } catch (e) {
      debugPrint('Erro ao carregar unread notifications: $e');
    }
  }

  // ------------------ JOBS (VIEW v_provider_jobs_public) -----------------------

  Future<void> _loadJobsFromView() async {
    try {
      setState(() => _loadingJobs = true);

      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _jobs = [];
          _newJobsCount = 0;
          _loadingJobs = false;
        });
        return;
      }

      final rows = await _supabase.from('v_provider_jobs_public').select('''
            id,
            title,
            description,
            service_detected,
            status,
            city,
            state,
            lat,
            lng,
            created_at,
            photos
          ''').order('created_at', ascending: false).limit(50);

      final list = <Map<String, dynamic>>[];
      for (final r in rows as List<dynamic>) {
        list.add(Map<String, dynamic>.from(r as Map));
      }

      if (!mounted) return;
      setState(() {
        _jobs = list;
        _newJobsCount = list.length;
        _loadingJobs = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar v_provider_jobs_public: $e');
      if (!mounted) return;
      setState(() => _loadingJobs = false);
    }
  }

  // ------------------ BANNERS SUPABASE -----------------------
  // (Depois a gente troca para uma view pública, se você quiser blindar partner_banners.)

  Future<void> _loadBanners() async {
    try {
      final rows = await _supabase
          .from('partner_banners')
          .select('title, subtitle, image_path, action_type, action_value')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final List<_HomeBanner> list = [];

      for (final row in rows as List<dynamic>) {
        final rawPath = (row['image_path'] as String).trim();

        if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
          list.add(
            _HomeBanner(
              title: row['title'] ?? '',
              subtitle: row['subtitle'],
              imageUrl: rawPath,
              actionType: row['action_type'],
              actionValue: row['action_value'],
            ),
          );
          continue;
        }

        final cleanedPath = rawPath.startsWith('banners/')
            ? rawPath.substring('banners/'.length)
            : rawPath;

        final publicUrl =
            _supabase.storage.from('banners').getPublicUrl(cleanedPath);

        list.add(
          _HomeBanner(
            title: row['title'] ?? '',
            subtitle: row['subtitle'],
            imageUrl: publicUrl,
            actionType: row['action_type'],
            actionValue: row['action_value'],
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _banners = list;
        _loadingBanners = false;
      });

      _startBannerAutoScroll();
    } catch (e) {
      debugPrint('ERRO _loadBanners: $e');
      if (!mounted) return;
      setState(() => _loadingBanners = false);
    }
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    if (_banners.length <= 1) return;

    _bannerTimer = Timer.periodic(
      const Duration(seconds: 4),
      (Timer timer) {
        if (!_bannerController.hasClients || _banners.isEmpty) return;

        int next = _currentBannerPage + 1;
        if (next >= _banners.length) next = 0;

        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );

        _currentBannerPage = next;
      },
    );
  }

  void _onBannerTap(_HomeBanner banner) {
    debugPrint("Banner clicado: ${banner.title}");
  }

  // ----------------- TIME --------------------

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

  void _openJobDetails(Map<String, dynamic> job) {
    final id = job['id'];
    if (id == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(jobId: id.toString()),
      ),
    ).then((_) {
      _loadJobsFromView();
    });
  }

  Future<void> _reloadAll() async {
    await _loadProviderHeader();
    await Future.wait([
      _loadJobsFromView(),
      _loadBanners(),
      _loadUnreadNotifications(),
    ]);
  }

  // ------------------ BUILD -----------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: RefreshIndicator(
        onRefresh: _reloadAll,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildHeaderAndStaticCards(),
            _buildJobsList(),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
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
                  _loadingHeader ? 'Carregando...' : _providerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isVerified)
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
                  _loadingHeader ? 'Carregando...' : _locationLabel,
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
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NotificationsPage(currentUserRole: 'provider'),
                    ),
                  );
                  _loadUnreadNotifications();
                },
              ),
              if (_unreadNotifications > 0)
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
                      _unreadNotifications > 9
                          ? '9+'
                          : _unreadNotifications.toString(),
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

  SliverToBoxAdapter _buildHeaderAndStaticCards() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Área de atendimento (view v_provider_me -> city)
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
                    child: Icon(
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
                          _loadingHeader ? 'Carregando...' : _locationLabel,
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

            // CARD LOJAS PARCEIRAS
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
                    SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: _roxo,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Banners
            if (_loadingBanners)
              const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_banners.isEmpty)
              const SizedBox(height: 0)
            else
              SizedBox(
                height: 150,
                child: PageView.builder(
                  controller: _bannerController,
                  itemCount: _banners.length,
                  onPageChanged: (i) => _currentBannerPage = i,
                  itemBuilder: (context, index) {
                    final banner = _banners[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: () => _onBannerTap(banner),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            banner.imageUrl,
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
              ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Novos serviços (${_newJobsCount.toString()})',
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

  Widget _buildJobsList() {
    if (_loadingJobs) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_jobs.isEmpty) {
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
          final job = _jobs[index];
          final title = (job['title'] as String?) ?? 'Serviço disponível';
          final desc = (job['description'] as String?) ?? 'Sem descrição.';
          final city = (job['city'] as String?)?.trim() ?? '';
          final uf = (job['state'] as String?)?.trim() ?? '';
          final createdAt = job['created_at']?.toString();

          final thumbUrl = _firstThumbFromPhotos(job['photos']);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              index == 0 ? 0 : 4,
              16,
              index == _jobs.length - 1 ? 16 : 4,
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
        childCount: _jobs.length,
      ),
    );
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
}

// Card compacto (somente dados da view)
class _JobPublicCard extends StatelessWidget {
  final String title;
  final String description;
  final String location;
  final String ago;
  final String? thumbUrl;
  final VoidCallback? onDetails;

  const _JobPublicCard({
    required this.title,
    required this.description,
    required this.location,
    required this.ago,
    this.thumbUrl,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF0DAA00);
    const Color roxo = Color(0xFF3B246B);

    return Container(
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

// BANNER MODEL -----------------------------
class _HomeBanner {
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? actionType;
  final String? actionValue;

  _HomeBanner({
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.actionType,
    this.actionValue,
  });
}
