import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:renthus/screens/client_home_page.dart';
import 'package:renthus/screens/client_my_jobs_page.dart';
import 'package:renthus/screens/client_chats_page.dart';
import 'package:renthus/screens/client_account_page.dart';
import 'package:renthus/screens/create_job_bottom_sheet.dart';

class ClientMainPage extends ConsumerStatefulWidget {
  const ClientMainPage({super.key});

  @override
  ConsumerState<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends ConsumerState<ClientMainPage> {
  int _currentIndex = 0;

  // Abas do cliente (ordem deve bater com o bottom nav)
  final List<Widget> _pages = const [
    ClientHomePage(),
    ClientMyJobsPage(),
    ClientChatsPage(),
    ClientAccountPage(),
  ];

  @override
  void initState() {
    super.initState();
    _printFcmToken();
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
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);
    const laranja = Color(0xFFFF6600);

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
                    ),
                    const Spacer(),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.chat_outlined,
                      label: 'Chat',
                      activeColor: laranja,
                    ),
                    const SizedBox(width: 10),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.person_outline,
                      label: 'Conta',
                      activeColor: laranja,
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
                    GestureDetector(
                      onTap: () async {
                        final jobId = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const CreateJobBottomSheet(),
                        );

                        if (jobId != null && jobId.isNotEmpty) {
                          setState(() => _currentIndex = 0);
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: laranja,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
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
  }) {
    final bool isActive = _currentIndex == index;
    final color = isActive ? activeColor : Colors.grey;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
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
