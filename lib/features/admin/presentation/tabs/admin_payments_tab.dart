import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class AdminPaymentsTab extends ConsumerStatefulWidget {
  const AdminPaymentsTab({super.key});

  @override
  ConsumerState<AdminPaymentsTab> createState() => _AdminPaymentsTabState();
}

class _AdminPaymentsTabState extends ConsumerState<AdminPaymentsTab> {

  bool _loading = true;
  bool _onlyProblems = true;

  List<Map<String, dynamic>> _items = [];

  final _problemStatuses = [
    'failed',
    'error',
    'refund_pending',
    'refunded',
    'chargeback',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final supabase = ref.read(supabaseProvider);
    var query = supabase.from('v_admin_payments').select();

    if (_onlyProblems) {
      query = query.inFilter('status', _problemStatuses);
    }

    final res = await query.order('created_at', ascending: false);

    setState(() {
      _items = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  String _money(num? v) {
    if (v == null) return '-';
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final supabase = ref.read(supabaseProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Problemas'),
                selected: _onlyProblems,
                onSelected: (_) {
                  setState(() => _onlyProblems = true);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Todos'),
                selected: !_onlyProblems,
                onSelected: (_) {
                  setState(() => _onlyProblems = false);
                  _load();
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('Nenhum pagamento encontrado.'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final p = _items[i];

                    final bruto = p['amount_total'] as num?;
                    final plataforma = p['amount_platform'] as num?;
                    final prov = p['amount_provider'] as num?;
                    final gatewayFee = (p['payment_method_fee'] ?? 0) +
                        (p['payment_fixed_fee'] ?? 0);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.payments),
                        title: Text(
                          '${p['status']} • ${_money(bruto)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'job: ${p['job_id']}\n'
                          'método: ${p['payment_method'] ?? '-'}\n'
                          'plataforma (15%): ${_money(plataforma)}\n'
                          'taxas gateway: ${_money(gatewayFee)}\n'
                          'prestador líquido: ${_money(prov)}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            await supabase.rpc(
                              'admin_set_payment_status',
                              params: {
                                'p_payment_id': p['id'],
                                'p_new_status': v,
                              },
                            );
                            _load();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'approved',
                              child: Text('Marcar como aprovado'),
                            ),
                            PopupMenuItem(
                              value: 'refunded',
                              child: Text('Marcar como reembolsado'),
                            ),
                            PopupMenuItem(
                              value: 'failed',
                              child: Text('Marcar como erro'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
