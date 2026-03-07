import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class AdminDisputeDetailsPage extends ConsumerStatefulWidget {

  const AdminDisputeDetailsPage({super.key, required this.disputeId});
  final String disputeId;

  @override
  ConsumerState<AdminDisputeDetailsPage> createState() =>
      _AdminDisputeDetailsPageState();
}

class _AdminDisputeDetailsPageState extends ConsumerState<AdminDisputeDetailsPage> {

  Map<String, dynamic>? dispute;
  List<Map<String, dynamic>> photos = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supabase = ref.read(supabaseProvider);
    final d = await supabase
        .from('v_admin_disputes')
        .select()
        .eq('id', widget.disputeId)
        .single();

    final p = await supabase
        .from('dispute_photos')
        .select()
        .eq('dispute_id', widget.disputeId);

    setState(() {
      dispute = d;
      photos = List<Map<String, dynamic>>.from(p);
      loading = false;
    });
  }

  Future<void> _setStatus(String status) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmar $status'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Observação (opcional)'),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final supabase = ref.read(supabaseProvider);
              await supabase.rpc(
                'admin_set_dispute_status',
                params: {
                  'p_dispute_id': widget.disputeId,
                  'p_new_status': status,
                  'p_resolution':
                      controller.text.isEmpty ? null : controller.text,
                },
              );
              Navigator.pop(context);
              _load();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String? v) {
    if (v == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(v).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final d = dispute!;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe da Disputa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Status', d['status']),
            _row('Job', d['job_title']),
            _row('Cidade', d['job_city']),
            _row('Cliente', d['client_name']),
            _row('Prestador', d['provider_name']),
            _row('Aberta em', _fmtDate(d['created_at'])),
            _row('SLA', _fmtDate(d['response_deadline_at'])),
            _row('Refund', d['refund_amount']?.toString() ?? '-'),
            const SizedBox(height: 24),
            const Text('Fotos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (photos.isEmpty) const Text('Sem fotos.') else Wrap(
                    spacing: 8,
                    children: photos
                        .map(
                          (p) => Image.network(
                            p['photo_url'],
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                        .toList(),
                  ),
            const SizedBox(height: 32),
            const Text('Ações administrativas',
                style: TextStyle(fontWeight: FontWeight.bold),),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _setStatus('resolved'),
                  child: const Text('Resolver'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _setStatus('refunded'),
                  child: const Text('Reembolsar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(l)),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
