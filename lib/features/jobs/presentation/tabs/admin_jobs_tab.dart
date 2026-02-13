import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';

class AdminJobsTab extends ConsumerStatefulWidget {
  const AdminJobsTab({super.key});

  @override
  ConsumerState<AdminJobsTab> createState() => _AdminJobsTabState();
}

class _AdminJobsTabState extends ConsumerState<AdminJobsTab> {
  bool actionLoading = false;
  String selectedStatus = 'all';

  static const statuses = <String>[
    'all',
    'waiting_providers',
    'accepted',
    'on_the_way',
    'in_progress',
    'completed',
    'cancelled',
    'dispute',
  ];

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmText = 'Confirmar',
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _runJobAction({
    required String action,
    required Map<String, dynamic> job,
  }) async {
    if (actionLoading) return;

    final jobId = job['id'];
    if (jobId == null) {
      _toast('Job inválido: sem ID.');
      return;
    }

    if (action == 'complete') {
      final ok = await _confirmAction(
        title: 'Forçar conclusão',
        message:
            'Você tem certeza que deseja marcar este job como COMPLETED?\n\nID: $jobId',
        confirmText: 'Concluir',
      );
      if (!ok) return;
    }

    if (action == 'cancel') {
      final ok = await _confirmAction(
        title: 'Forçar cancelamento',
        message: 'Você tem certeza que deseja CANCELAR este job?\n\nID: $jobId',
        confirmText: 'Cancelar job',
      );
      if (!ok) return;
    }

    if (action == 'dispute') {
      final ok = await _confirmAction(
        title: 'Abrir disputa',
        message:
            'Você tem certeza que deseja abrir DISPUTA para este job?\n\nID: $jobId',
        confirmText: 'Abrir disputa',
      );
      if (!ok) return;
    }

    setState(() => actionLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      if (action == 'complete') {
        await supabase.rpc('admin_force_complete_job', params: {
          'p_job_id': jobId,
          'p_note': 'Forçado via dashboard admin',
        });
        _toast('Job marcado como completed.');
      } else if (action == 'cancel') {
        await supabase.rpc('admin_force_cancel_job', params: {
          'p_job_id': jobId,
          'p_reason': 'Cancelado via dashboard admin',
        });
        _toast('Job cancelado com sucesso.');
      } else if (action == 'dispute') {
        await supabase.rpc('admin_open_dispute', params: {
          'p_job_id': jobId,
          'p_reason': 'Disputa aberta via dashboard admin',
        });
        _toast('Disputa aberta com sucesso.');
      }
      ref.invalidate(adminJobsProvider);
    } on PostgrestException catch (e) {
      _toast('Erro (RLS/SQL): ${e.message}');
    } catch (e) {
      _toast('Erro ao executar ação: $e');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(adminJobsProvider);
    final allJobs = dataAsync.valueOrNull ?? [];
    final jobs = selectedStatus == 'all'
        ? allJobs
        : allJobs
            .where(
                (j) => (j['status']?.toString() ?? '') == selectedStatus,
            )
            .toList();

    return Column(
      children: [
        if (actionLoading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DropdownButton<String>(
                value: selectedStatus,
                items: statuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedStatus = value);
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Recarregar',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(adminJobsProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: dataAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro: $e'),
              ),
            ),
            data: (_) => jobs.isEmpty
                ? const Center(child: Text('Nenhum job encontrado.'))
                : ListView.separated(
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final job = jobs[index];

                      final title =
                          (job['title']?.toString().trim().isNotEmpty ?? false)
                              ? job['title'].toString()
                              : 'Sem título';

                      final status = job['status']?.toString() ?? '-';
                      final id = job['id']?.toString() ?? '-';
                      final paymentStatus =
                          job['payment_status']?.toString() ?? '-';

                      String money = '-';
                      final dailyTotal = job['daily_total'];
                      final price = job['price'];
                      if (dailyTotal != null) {
                        money = 'R\$ ${dailyTotal.toString()}';
                      } else if (price != null) {
                        money = 'R\$ ${price.toString()}';
                      }

                      return ListTile(
                        leading: const Icon(Icons.work_outline),
                        title: Text(title),
                        subtitle: Text(
                          'Status: $status • Pagamento: $paymentStatus\nValor: $money\nID: $id',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Ações admin',
                          onSelected: (value) =>
                              _runJobAction(action: value, job: job),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'complete',
                              child: Text('Forçar conclusão'),
                            ),
                            PopupMenuItem(
                              value: 'cancel',
                              child: Text('Forçar cancelamento'),
                            ),
                            PopupMenuItem(
                              value: 'dispute',
                              child: Text('Abrir disputa'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
