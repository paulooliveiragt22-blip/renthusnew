import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';

import 'package:renthus/screens/provider_home_page.dart';
import 'package:renthus/screens/provider_my_jobs_page.dart';
import 'package:renthus/screens/provider_financial_page.dart';
import 'package:renthus/screens/provider_account_page.dart';

class ProviderMainPage extends ConsumerStatefulWidget {
  const ProviderMainPage({super.key});

  @override
  ConsumerState<ProviderMainPage> createState() => _ProviderMainPageState();
}

class _ProviderMainPageState extends ConsumerState<ProviderMainPage> {
  int selectedIndex = 0;
  bool loading = true;

  // Agora guardamos o “me” vindo da view
  Map<String, dynamic>? providerMe;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      context.goToLogin();
      return;
    }

    try {
      setState(() => loading = true);

      final p = await supabase.from('v_provider_me').select('''
            provider_id,
            onboarding_completed
          ''').maybeSingle();

      if (p == null) {
        // Usuário logado, mas ainda não tem registro provider
        if (!mounted) return;
        context.goToProviderServiceSelection();
        return;
      }

      final me = Map<String, dynamic>.from(p as Map);

      final onboardingCompleted = me['onboarding_completed'] == true;

      if (!onboardingCompleted) {
        if (!mounted) return;
        context.goToProviderAddressStep3();
        return;
      }

      if (!mounted) return;
      setState(() {
        providerMe = me;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil do prestador: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = <Widget>[
      const ProviderHomePage(), // 0
      const ProviderMyJobsPage(), // 1
      const ProviderFinancialPage(), // 2
      const ProviderAccountPage(), // 3
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: pages[selectedIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 8,
          currentIndex: selectedIndex,
          onTap: (index) => setState(() => selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFF6600),
          unselectedItemColor: const Color(0xFF8E8E99),
          selectedIconTheme:
              const IconThemeData(color: Color(0xFF3B246B), size: 20),
          unselectedIconTheme:
              const IconThemeData(color: Color(0xFF3B246B), size: 20),
          selectedFontSize: 10,
          unselectedFontSize: 9,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inbox),
              label: 'Pedidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'Meus Pedidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money),
              label: 'Financeiro',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Minha Conta',
            ),
          ],
        ),
      ),
    );
  }
}
