import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/notification_badge_provider.dart';
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

class _ProviderMainPageState extends ConsumerState<ProviderMainPage>
    with WidgetsBindingObserver {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationBadgeController.instance.loadFromDatabase();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationBadgeController.instance.loadFromDatabase();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => selectedIndex = index);

    switch (index) {
      case 0:
      case 1:
        NotificationBadgeController.instance.clearBadge(BadgeSection.jobs);
        break;
      case 3:
        NotificationBadgeController.instance.clearBadge(BadgeSection.account);
        break;
    }
  }

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

        final badgeCtrl = ref.watch(notificationBadgeControllerProvider);
        final jobsBadgeCount = badgeCtrl.jobsCount;
        final accountBadgeCount = badgeCtrl.accountCount;
        final hasVerifBadge = showBadge;

        return Scaffold(
          backgroundColor: const Color(0xFFF2F2F2),
          body: pages[selectedIndex],
          bottomNavigationBar: SafeArea(
            top: false,
            child: BottomNavigationBar(
              backgroundColor: Colors.white,
              elevation: 8,
              currentIndex: selectedIndex,
              onTap: _onTabTap,
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
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: jobsBadgeCount > 0,
                    label: Text(
                      jobsBadgeCount > 99 ? '99+' : '$jobsBadgeCount',
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.inbox),
                  ),
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
                  icon: Badge(
                    isLabelVisible: hasVerifBadge || accountBadgeCount > 0,
                    label: accountBadgeCount > 0
                        ? Text(
                            accountBadgeCount > 99 ? '99+' : '$accountBadgeCount',
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                          )
                        : null,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.person_outline),
                  ),
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
