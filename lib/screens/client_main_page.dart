import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:renthus/core/providers/notification_badge_provider.dart';
import 'package:renthus/features/jobs/jobs.dart' show ClientMyJobsPage;
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/features/chat/chat.dart' show ClientChatsPage;
import 'package:renthus/screens/client_account_page.dart';
import 'package:renthus/screens/client_home_page.dart';
import 'package:renthus/screens/create_job_bottom_sheet.dart';

class ClientMainPage extends ConsumerStatefulWidget {
  const ClientMainPage({super.key});

  @override
  ConsumerState<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends ConsumerState<ClientMainPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _showTooltip = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  final List<Widget> _pages = const [
    ClientHomePage(),
    ClientMyJobsPage(),
    ClientChatsPage(),
    ClientAccountPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _printFcmToken();
    _checkFirstJobTooltip();
    NotificationBadgeController.instance.loadFromDatabase();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationBadgeController.instance.loadFromDatabase();
    }
  }

  Future<void> _checkFirstJobTooltip() async {
    final prefs = await SharedPreferences.getInstance();
    final created = prefs.getBool('first_job_created') ?? false;
    if (!created && mounted) {
      setState(() => _showTooltip = true);
      _pulseCtrl.repeat(reverse: true);
    }
  }

  void _onJobCreated() {
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('first_job_created', true),
    );
    if (_showTooltip && mounted) {
      setState(() => _showTooltip = false);
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  Future<void> _printFcmToken() async {
    // Só tenta pegar token em Android/iOS
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('TOKEN FCM (ClientMainPage): $token');
    } catch (e) {
      debugPrint('Erro ao obter FCM token: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 1:
        NotificationBadgeController.instance.clearBadge(BadgeSection.jobs);
        break;
      case 2:
        NotificationBadgeController.instance.clearBadge(BadgeSection.chat);
        break;
      case 3:
        NotificationBadgeController.instance.clearBadge(BadgeSection.account);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);
    const laranja = Color(0xFFFF6600);

    final activeJobs = ref.watch(clientActiveJobsProvider).valueOrNull ?? [];
    final shouldPulse = _showTooltip && activeJobs.isEmpty;

    // Watch badge state
    final badgeCtrl = ref.watch(notificationBadgeControllerProvider);

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: SizedBox(
        height: 86,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Barra de navegação “reta”
            Positioned.fill(
              top: 16, // dá espaço pra bolinha sair pra cima
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      label: 'Início',
                      activeColor: laranja,
                    ),
                    const SizedBox(width: 10),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.receipt_long_outlined,
                      label: 'Pedidos',
                      activeColor: laranja,
                      badgeCount: badgeCtrl.jobsCount,
                    ),
                    const Spacer(),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.chat_outlined,
                      label: 'Chat',
                      activeColor: laranja,
                      badgeCount: badgeCtrl.chatCount,
                    ),
                    const SizedBox(width: 10),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.person_outline,
                      label: 'Conta',
                      activeColor: laranja,
                      badgeCount: badgeCtrl.accountCount,
                    ),
                  ],
                ),
              ),
            ),

            // Botão central NOVO PEDIDO
            Positioned(
              top: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: shouldPulse
                          ? 'Toque aqui para solicitar um serviço'
                          : '',
                      preferBelow: false,
                      verticalOffset: 36,
                      child: GestureDetector(
                        onTap: () async {
                          final jobId = await showModalBottomSheet<String>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const CreateJobBottomSheet(),
                          );

                          if (jobId != null && jobId.isNotEmpty) {
                            _onJobCreated();
                            setState(() => _currentIndex = 0);
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            final scale =
                                shouldPulse ? _pulseAnim.value : 1.0;
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: laranja,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x2E000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.add,
                                color: roxo,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'PEDIDO',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.black87,
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

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    int badgeCount = 0,
  }) {
    final bool isActive = _currentIndex == index;
    final color = isActive ? activeColor : Colors.grey;

    return InkWell(
      onTap: () => _onTabTap(index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
              backgroundColor: Colors.red,
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
