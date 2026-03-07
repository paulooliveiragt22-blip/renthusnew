import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  Future<AdminAlerts> loadAlerts() async {
    final a = await _client.from('v_admin_disputes_sla_risk').select('id');
    final b = await _client.from('v_admin_payments_stuck').select('id');
    final c = await _client.from('v_admin_jobs_stalled').select('id');
    return AdminAlerts(
      disputesSla: (a as List).length,
      paymentsStuck: (b as List).length,
      jobsStalled: (c as List).length,
    );
  }
}

class AdminAlerts {
  const AdminAlerts({
    required this.disputesSla,
    required this.paymentsStuck,
    required this.jobsStalled,
  });
  final int disputesSla;
  final int paymentsStuck;
  final int jobsStalled;
}
