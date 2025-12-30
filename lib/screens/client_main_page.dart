import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'client_home_page.dart';
import 'client_my_jobs_page.dart';
import 'client_chats_page.dart';
import 'client_account_page.dart';
import 'create_job_bottom_sheet.dart';

class ClientMainPage extends StatefulWidget {
  const ClientMainPage({super.key});

  @override
  State<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends State<ClientMainPage> {
  int _currentIndex = 0;

  // ✅ Cada aba tem seu próprio Navigator (para manter o bottom bar sempre visível)
  final List<GlobalKey<NavigatorState>> _tabNavKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
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
      // ignore: avoid_print
      print('TOKEN FCM (ClientMainPage): $token');
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao obter FCM token: $e');
    }
  }

  Future<bool> _onWillPop() async {
    final currentNavigator = _tabNavKeys[_currentIndex].currentState;
    if (currentNavigator == null) return true;

    // Se conseguir voltar dentro da aba, não fecha o app
    if (await currentNavigator.maybePop()) return false;

    // Se está em outra aba e não tem rota pra voltar, volta pra Home
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    // Se já está na Home e não tem mais nada pra voltar, deixa sair
    return true;
  }

  void _onTapTab(int index) {
    if (index == _currentIndex) {
      // Re-tap na aba atual: volta pro início da pilha daquela aba
      _tabNavKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _currentIndex = index);
  }

  Widget _buildTabNavigator({
    required int index,
    required Widget rootPage,
  }) {
    return Navigator(
      key: _tabNavKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => rootPage,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);
    const laranja = Color(0xFFFF6600);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // ✅ Body com pilha de Navigators (um por aba)
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(index: 0, rootPage: const ClientHomePage()),
            _buildTabNavigator(index: 1, rootPage: const ClientMyJobsPage()),
            _buildTabNavigator(index: 2, rootPage: const ClientChatsPage()),
            _buildTabNavigator(index: 3, rootPage: const ClientAccountPage()),
          ],
        ),

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
                        onTap: _onTapTab,
                      ),
                      const SizedBox(width: 10),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.receipt_long_outlined,
                        label: 'Pedidos',
                        activeColor: laranja,
                        onTap: _onTapTab,
                      ),
                      const Spacer(),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.chat_outlined,
                        label: 'Chat',
                        activeColor: laranja,
                        onTap: _onTapTab,
                      ),
                      const SizedBox(width: 10),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.person_outline,
                        label: 'Conta',
                        activeColor: laranja,
                        onTap: _onTapTab,
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
                            // volta para a Home mantendo o bottom bar
                            setState(() => _currentIndex = 0);
                            // opcional: garantir que a Home esteja no root
                            _tabNavKeys[0]
                                .currentState
                                ?.popUntil((r) => r.isFirst);
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
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    required void Function(int) onTap,
  }) {
    final bool isActive = _currentIndex == index;
    final color = isActive ? activeColor : Colors.grey;

    return InkWell(
      onTap: () => onTap(index),
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
