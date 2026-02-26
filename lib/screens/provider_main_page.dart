import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(providerMeFullProvider);
    final user = ref.watch(supabaseProvider).auth.currentUser;

    return meAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ErrorHandler.friendlyErrorMessage(e)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(providerMeFullProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      data: (me) {
        final vStatus =
            (me?['verification_status'] as String?)?.trim() ?? 'pending';
        final showBadge = vStatus != 'active';

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.goToLogin();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (me == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.goToProviderServiceSelection();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final onboardingCompleted =
            (me['onboarding_completed'] as bool?) ?? false;
        if (!onboardingCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.goToProviderAddressStep3();
          });
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
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.inbox),
                  label: 'Pedidos',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt),
                  label: 'Meus Pedidos',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.attach_money),
                  label: 'Financeiro',
                ),
                BottomNavigationBarItem(
                  icon: showBadge
                      ? const Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(Icons.person_outline),
                            Positioned(
                              right: -4,
                              top: -4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(width: 8, height: 8),
                              ),
                            ),
                          ],
                        )
                      : const Icon(Icons.person_outline),
                  label: 'Minha Conta',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
