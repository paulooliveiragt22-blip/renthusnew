import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/admin/data/providers/admin_providers.dart';
import 'package:renthus/features/admin/presentation/tabs/admin_disputes_tab.dart';
import 'package:renthus/features/admin/presentation/tabs/admin_finance_tab.dart';
import 'package:renthus/features/admin/presentation/tabs/admin_jobs_tab.dart';
import 'package:renthus/features/admin/presentation/tabs/admin_logs_tab.dart';
import 'package:renthus/features/admin/presentation/tabs/admin_payments_tab.dart';
import 'package:renthus/features/admin/presentation/tabs/admin_users_tab.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final supabase = ref.read(supabaseProvider);
    await supabase.auth.signOut();
    if (!mounted) return;
    context.goToLogin();
  }

  void _goToTab(int index) {
    _controller.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF3B246B);
    final alertsAsync = ref.watch(adminAlertsProvider);
    final alerts = alertsAsync.valueOrNull;
    final loadingAlerts = alertsAsync.isLoading;
    final hasAlerts = alerts != null &&
        (alerts.disputesSla > 0 ||
            alerts.paymentsStuck > 0 ||
            alerts.jobsStalled > 0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: purple,
        title: const Text('Admin • Renthus'),
        actions: [
          IconButton(
            tooltip: 'Recarregar alertas',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminAlertsProvider),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.gavel), text: 'Disputas'),
            Tab(icon: Icon(Icons.payments), text: 'Pagamentos'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Financeiro'),
            Tab(icon: Icon(Icons.work), text: 'Jobs'),
            Tab(icon: Icon(Icons.people), text: 'Usuários'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Logs'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ALERTAS NO TOPO
          if (loadingAlerts) const LinearProgressIndicator(minHeight: 2),

          if (hasAlerts && alerts != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (alerts.disputesSla > 0)
                    _AlertCard(
                      title: 'Disputas com SLA vencido',
                      subtitle: '${alerts.disputesSla} em risco',
                      icon: Icons.gavel,
                      onTap: () => _goToTab(0),
                    ),
                  if (alerts.paymentsStuck > 0)
                    _AlertCard(
                      title: 'Pagamentos travados',
                      subtitle: '${alerts.paymentsStuck} pendentes +24h',
                      icon: Icons.payments,
                      onTap: () => _goToTab(1),
                    ),
                  if (alerts.jobsStalled > 0)
                    _AlertCard(
                      title: 'Jobs parados',
                      subtitle: '${alerts.jobsStalled} sem atualização +48h',
                      icon: Icons.work,
                      onTap: () => _goToTab(3),
                    ),
                ],
              ),
            ),

          // Tabs
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [
                AdminDisputesTab(),
                AdminPaymentsTab(),
                AdminFinanceTab(),
                AdminJobsTab(),
                AdminUsersTab(),
                AdminLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {

  const _AlertCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
