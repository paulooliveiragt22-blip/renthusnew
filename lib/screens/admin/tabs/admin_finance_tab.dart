import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class AdminFinanceTab extends ConsumerStatefulWidget {
  const AdminFinanceTab({super.key});

  @override
  ConsumerState<AdminFinanceTab> createState() => _AdminFinanceTabState();
}

class _AdminFinanceTabState extends ConsumerState<AdminFinanceTab> {

  bool _loading = true;

  num _bruto = 0;
  num _plataforma = 0;
  num _gateway = 0;
  num _liquido = 0;
  num _ticket = 0;

  Map<String, int> _methods = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final supabase = ref.read(supabaseProvider);
    final payments = await supabase
        .from('v_admin_payments')
        .select()
        .eq('status', 'approved');

    if (payments.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    num total = 0;
    num platform = 0;
    num gateway = 0;

    final methods = <String, int>{};

    for (final p in payments) {
      total += p['amount_total'] ?? 0;
      platform += p['amount_platform'] ?? 0;
      gateway += (p['payment_method_fee'] ?? 0) + (p['payment_fixed_fee'] ?? 0);

      final m = p['payment_method'] ?? 'outro';
      methods[m] = (methods[m] ?? 0) + 1;
    }

    setState(() {
      _bruto = total;
      _plataforma = platform;
      _gateway = gateway;
      _liquido = platform - gateway;
      _ticket = total / payments.length;
      _methods = methods;
      _loading = false;
    });
  }

  String _money(num v) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumo Financeiro',
              style: Theme.of(context).textTheme.titleLarge,),
          const SizedBox(height: 16),
          _item('Faturamento bruto', _money(_bruto)),
          _item('Comissão Renthus (15%)', _money(_plataforma)),
          _item('Taxas gateway', _money(_gateway)),
          _item('Receita líquida', _money(_liquido)),
          _item('Ticket médio', _money(_ticket)),
          const SizedBox(height: 24),
          Text('Meios de pagamento',
              style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(height: 8),
          ..._methods.entries.map(
            (e) => _item(e.key, '${e.value} pagamentos'),
          ),
        ],
      ),
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
