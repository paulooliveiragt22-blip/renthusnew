import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class AdminLogsTab extends ConsumerStatefulWidget {
  const AdminLogsTab({super.key});

  @override
  ConsumerState<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends ConsumerState<AdminLogsTab> {

  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase
          .from('audit_logs')
          .select(
              'id, entity, entity_id, action, payload, performed_by, created_at',)
          .order('created_at', ascending: false)
          .limit(200);

      setState(() {
        rows = (res as List).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } on PostgrestException catch (e) {
      setState(() {
        error = e.message;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = '$e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM HH:mm');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Text('Logs (audit_logs)',
                  style: TextStyle(fontWeight: FontWeight.w800),),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text('Erro: $error'))
                  : rows.isEmpty
                      ? const Center(child: Text('Sem logs.'))
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1, color: Colors.black.withOpacity(0.08),),
                          itemBuilder: (context, i) {
                            final l = rows[i];
                            final createdAt =
                                DateTime.tryParse('${l['created_at']}')
                                    ?.toLocal();

                            final payload = l['payload'];
                            String payloadShort = '';
                            try {
                              if (payload != null) {
                                final s = jsonEncode(payload);
                                payloadShort = s.length > 120
                                    ? '${s.substring(0, 120)}…'
                                    : s;
                              }
                            } catch (_) {}

                            return ListTile(
                              leading: const Icon(Icons.receipt_long_rounded),
                              title: Text(
                                  '${l['action'] ?? '-'} • ${l['entity'] ?? '-'}',),
                              subtitle: Text(
                                'entity_id: ${l['entity_id'] ?? '-'}\n'
                                'by: ${l['performed_by'] ?? '-'}'
                                '${createdAt != null ? ' • ${df.format(createdAt)}' : ''}'
                                '${payloadShort.isNotEmpty ? '\n$payloadShort' : ''}',
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
