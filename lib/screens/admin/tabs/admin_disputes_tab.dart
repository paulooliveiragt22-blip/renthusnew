import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class AdminDisputesTab extends ConsumerStatefulWidget {
  const AdminDisputesTab({super.key});

  @override
  ConsumerState<AdminDisputesTab> createState() => _AdminDisputesTabState();
}

class _AdminDisputesTabState extends ConsumerState<AdminDisputesTab> {

  String _status = 'open';
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  final _statuses = ['open', 'resolved', 'refunded'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final supabase = ref.read(supabaseProvider);
    final res = await supabase
        .from('v_admin_disputes')
        .select()
        .eq('status', _status)
        .order('created_at', ascending: false);

    setState(() {
      _items = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _status,
                items: _statuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _status = v);
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
              ? const Center(child: Text('Nenhuma disputa encontrada.'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final d = _items[i];
                    final created = DateFormat('dd/MM HH:mm').format(
                      DateTime.parse(d['created_at']).toLocal(),
                    );

                    return ListTile(
                      leading: const Icon(Icons.gavel),
                      title: Text(
                        '${d['status']} • ${d['id']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'job: ${d['job_id']}\n'
                        'cliente: ${d['client_name'] ?? '-'}\n'
                        'prestador: ${d['provider_name'] ?? '-'}\n'
                        'aberta: $created\n'
                        'refund: ${d['refund_amount'] ?? '-'}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
