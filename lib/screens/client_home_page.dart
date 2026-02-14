// lib/screens/client_home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:renthus/core/providers/legacy_notification_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/core/providers/service_provider.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/widgets/service_card.dart';
import 'package:renthus/models/home_service.dart';
import 'package:renthus/screens/create_job_bottom_sheet.dart';

import 'package:renthus/screens/notifications_page.dart';
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

  // endereço / cliente
  String? _addressLine;
  String? _clientName;
  String? _clientCity;
  bool _loadingAddress = true;

  // notificações
  int _unreadCount = 0;

  // serviços
  bool _loadingServices = true;
  String? _servicesError;
  List<HomeService> _services = [];

  // jobs recentes (apenas waiting_providers)
  bool _loadingRecentJobs = true;
  String? _recentJobsError;
  List<Map<String, dynamic>> _recentJobs = [];

  // banners
  bool _loadingBanners = true;
  List<_HomeBanner> _banners = [];
  late PageController _bannerController;
  Timer? _bannerTimer;
  static const int _kInitialBannerPage = 1000;
  int _currentBannerPage = _kInitialBannerPage;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(
      viewportFraction: 0.92,
      initialPage: _kInitialBannerPage,
    );

    _loadAddress();
    _loadUnreadCount();
    _loadServices();
    _loadRecentJobs();
    _loadBanners();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // ---------------- CLIENTE ----------------

  Future<void> _loadAddress() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _addressLine = 'Endereço não informado';
        _clientName = null;
        _clientCity = null;
        _loadingAddress = false;
      });
      return;
    }

    try {
      final res = await supabase
          .from('clients')
          .select('address_street, address_number, full_name, city')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (res == null) {
        setState(() {
          _addressLine = 'Endereço não informado';
          _clientName = null;
          _clientCity = null;
          _loadingAddress = false;
        });
        return;
      }

      final street = (res['address_street'] ?? '').toString();
      final number = (res['address_number'] ?? '').toString();
      final fullName = (res['full_name'] ?? '').toString();
      final city = (res['city'] ?? '').toString();

      String line;
      if (street.isEmpty) {
        line = 'Endereço não informado';
      } else if (number.isEmpty) {
        line = street;
      } else {
        line = '$street, $number';
      }

      setState(() {
        _addressLine = line;
        _clientName = fullName.isEmpty ? null : fullName;
        _clientCity = city.isEmpty ? null : city;
        _loadingAddress = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar endereço do cliente: $e');
      if (!mounted) return;
      setState(() {
        _addressLine = 'Endereço não informado';
        _clientName = null;
        _clientCity = null;
        _loadingAddress = false;
      });
    }
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

  // ---------------- SERVIÇOS ----------------

  Future<void> _loadServices() async {
    try {
      setState(() {
        _loadingServices = true;
        _servicesError = null;
      });

      final serviceRepo = ref.read(serviceRepositoryProvider);
      final list = await serviceRepo.fetchHomeServices();

      if (!mounted) return;

      setState(() {
        _services = list;
        _loadingServices = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar serviços (cliente): $e');
      if (!mounted) return;
      setState(() {
        _servicesError = e.toString();
        _loadingServices = false;
      });
    }
  }

  // ---------------- JOBS RECENTES (NOVOS ORÇAMENTOS) ----------------

  Future<void> _loadRecentJobs() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _recentJobs = [];
        _loadingRecentJobs = false;
      });
      return;
    }

    try {
      setState(() {
        _loadingRecentJobs = true;
        _recentJobsError = null;
      });

      final rows = await supabase
          .from('jobs')
          .select('id, title, status, created_at')
          .eq('client_id', user.id)
          .eq('status', 'waiting_providers')
          .order('created_at', ascending: false)
          .limit(20);

      if (!mounted) return;

      _recentJobs = (rows as List<dynamic>).cast<Map<String, dynamic>>();

      setState(() {
        _loadingRecentJobs = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar jobs recentes (cliente): $e');
      if (!mounted) return;
      setState(() {
        _recentJobsError = e.toString();
        _loadingRecentJobs = false;
      });
    }
  }

  void _openMyJobs() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ClientMyJobsPage(),
      ),
    );
  }

  // ---------------- BANNERS ----------------

  Future<void> _loadBanners() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final rows = await supabase
          .from('partner_banners')
          .select('title, subtitle, image_path, action_type, action_value')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final List<_HomeBanner> list = [];

      for (final row in rows as List<dynamic>) {
        final rawPath = (row['image_path'] as String).trim();

        String imageUrl;
        if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
          imageUrl = rawPath;
        } else {
          final cleanedPath = rawPath.startsWith('banners/')
              ? rawPath.substring('banners/'.length)
              : rawPath;

          imageUrl =
              supabase.storage.from('banners').getPublicUrl(cleanedPath);
        }

        list.add(
          _HomeBanner(
            title: row['title'] ?? '',
            subtitle: row['subtitle'],
            imageUrl: imageUrl,
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
      debugPrint('Erro ao carregar banners (cliente): $e');
      if (!mounted) return;
      setState(() => _loadingBanners = false);
    }
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

  int _realBannerIndex(int virtualIndex) {
    if (_banners.isEmpty) return 0;
    return virtualIndex % _banners.length;
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
                          _clientName == null || _clientName!.isEmpty
                              ? '${_saudacaoHorario()} 👋'
                              : '${_saudacaoHorario()}, ${_primeiroNome(_clientName)} 👋',
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
                            _loadingAddress
                                ? 'Carregando endereço...'
                                : (_addressLine ?? 'Adicionar endereço'),
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
          await Future.wait([
            _loadAddress(),
            _loadUnreadCount(),
            _loadServices(),
            _loadRecentJobs(),
            _loadBanners(),
          ]);
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

                    // BANNERS
                    if (_loadingBanners)
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
                    else if (_banners.isNotEmpty)
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
                                if (_banners.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final index = _realBannerIndex(virtualIndex);
                                final banner = _banners[index];

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
                            children: List.generate(_banners.length, (index) {
                              final isActive =
                                  index == _realBannerIndex(_currentBannerPage);
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

                    _buildRecentJobsSection(), // card único com contagem

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
                child: _buildServicesSection(),
              ),
            ),

            // SEÇÕES FINAIS
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 14, 12, bottomPadding + 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopServicesSection(),
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

  Widget _buildRecentJobsSection() {
    if (_loadingRecentJobs) {
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
          const SizedBox(height: 6),
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      );
    }

    if (_recentJobsError != null || _recentJobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = _recentJobs.length;
    final title = count == 1
        ? 'Você tem 1 orçamento aguardando prestadores'
        : 'Você tem $count orçamentos aguardando prestadores';

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
        const SizedBox(height: 6),
        InkWell(
          onTap: _openMyJobs,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
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
                const Icon(
                  Icons.home_repair_service_outlined,
                  size: 24,
                  color: roxo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Aguardando prestadores interessados',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Ver em "Pedidos"',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesSection() {
    if (_loadingServices) {
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

    if (_servicesError != null) {
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
              _servicesError!,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadServices,
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

    if (_services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhum serviço configurado ainda.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final visible = _services
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

  Widget _buildTopServicesSection() {
    if (_services.isEmpty) return const SizedBox.shrink();

    final visible = _services
        .where(
          (s) =>
              (s.thumbUrl != null && s.thumbUrl!.isNotEmpty) ||
              (s.imageUrl != null && s.imageUrl!.isNotEmpty),
        )
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    final top3 = visible.take(3).toList();
    final city = _clientCity ?? 'sua região';

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
