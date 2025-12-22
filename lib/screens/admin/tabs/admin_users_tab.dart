import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final supabase = Supabase.instance.client;

  bool _showClients = true;
  bool _loading = true;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final table = _showClients ? 'clients' : 'providers';

    final res = await supabase
        .from(table)
        .select()
        .order('created_at', ascending: false);

    setState(() {
      _items = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  Future<void> _toggleBlock(Map<String, dynamic> u) async {
    final bool blocked = u['status'] == 'blocked';

    await supabase.rpc(
      'admin_set_user_block',
      params: {
        'p_user_id': _showClients ? u['id'] : u['user_id'],
        'p_block': !blocked,
        'p_reason': blocked ? null : 'Bloqueio administrativo',
      },
    );

    _load();
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
              ChoiceChip(
                label: const Text('Clientes'),
                selected: _showClients,
                onSelected: (_) {
                  setState(() => _showClients = true);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Prestadores'),
                selected: !_showClients,
                onSelected: (_) {
                  setState(() => _showClients = false);
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
              ? const Center(child: Text('Nenhum usuário encontrado.'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final u = _items[i];
                    final blocked = u['status'] == 'blocked';

                    return ListTile(
                      leading: Icon(
                        blocked ? Icons.block : Icons.person,
                        color: blocked ? Colors.red : null,
                      ),
                      title: Text(u['full_name'] ?? '-'),
                      subtitle: Text(
                        'cidade: ${u['city'] ?? '-'}\n'
                        'fone: ${u['phone'] ?? '-'}\n'
                        'status: ${u['status'] ?? 'active'}',
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () => _toggleBlock(u),
                        child: Text(
                          blocked ? 'Desbloquear' : 'Bloquear',
                          style: TextStyle(
                            color: blocked ? Colors.green : Colors.red,
                          ),
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
