import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../login_screen.dart';

import 'tabs/admin_disputes_tab.dart';
import 'tabs/admin_payments_tab.dart';
import 'tabs/admin_finance_tab.dart';
import 'tabs/admin_jobs_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'tabs/admin_logs_tab.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  final supabase = Supabase.instance.client;

  bool _loadingAlerts = true;
  int _disputesSla = 0;
  int _paymentsStuck = 0;
  int _jobsStalled = 0;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 6, vsync: this);
    _loadAlerts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadAlerts() async {
    setState(() => _loadingAlerts = true);
    try {
      final a = await supabase.from('v_admin_disputes_sla_risk').select('id');
      final b = await supabase.from('v_admin_payments_stuck').select('id');
      final c = await supabase.from('v_admin_jobs_stalled').select('id');

      setState(() {
        _disputesSla = (a as List).length;
        _paymentsStuck = (b as List).length;
        _jobsStalled = (c as List).length;
        _loadingAlerts = false;
      });
    } catch (_) {
      setState(() => _loadingAlerts = false);
    }
  }

  void _goToTab(int index) {
    _controller.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF3B246B);

    final hasAlerts =
        _disputesSla > 0 || _paymentsStuck > 0 || _jobsStalled > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: purple,
        title: const Text('Admin • Renthus'),
        actions: [
          IconButton(
            tooltip: 'Recarregar alertas',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
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
          // 🔴 ALERTAS NO TOPO
          if (_loadingAlerts) const LinearProgressIndicator(minHeight: 2),

          if (hasAlerts)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_disputesSla > 0)
                    _AlertCard(
                      title: 'Disputas com SLA vencido',
                      subtitle: '$_disputesSla em risco',
                      icon: Icons.gavel,
                      onTap: () => _goToTab(0),
                    ),
                  if (_paymentsStuck > 0)
                    _AlertCard(
                      title: 'Pagamentos travados',
                      subtitle: '$_paymentsStuck pendentes +24h',
                      icon: Icons.payments,
                      onTap: () => _goToTab(1),
                    ),
                  if (_jobsStalled > 0)
                    _AlertCard(
                      title: 'Jobs parados',
                      subtitle: '$_jobsStalled sem atualização +48h',
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
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AlertCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

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
