// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  String? _category;
  bool _loading = false;
  List<dynamic> _services = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _loading = true);
    try {
      var query = _client.from('services_catalog').select();

      final text = _searchCtrl.text.trim();
      if (text.isNotEmpty) {
        query = query.ilike('name', '%$text%');
      }
      if (_category != null && _category!.isNotEmpty) {
        query = query.eq('category_id', _category);
      }

      final res = await query.order('created_at', ascending: false);

      setState(() {
        _services = res;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar serviços: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createBooking(Map<String, dynamic> service) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para agendar um serviço')),
      );
      return;
    }

    final providerId = service['provider_id'];
    if (providerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço sem prestador vinculado')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar agendamento'),
        content: Text(
          'Deseja solicitar o serviço "${service['name']}" para o prestador?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('bookings').insert({
        'service_id': service['id'],
        'provider_id': providerId,
        'client_id': user.id,
        'status': 'pending',
        'scheduled_at': DateTime.now().toIso8601String(), // simples, por enquanto
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido criado com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar agendamento: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar serviços'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'O que você procura?',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadServices(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loadServices,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todas')),
                DropdownMenuItem(value: 'cleaning', child: Text('Limpeza')),
                DropdownMenuItem(value: 'construction', child: Text('Pedreiro')),
                DropdownMenuItem(value: 'moving', child: Text('Fretes')),
                DropdownMenuItem(value: 'other', child: Text('Outros')),
              ],
              onChanged: (v) {
                setState(() => _category = v);
                _loadServices();
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _services.isEmpty
                    ? const Center(child: Text('Nenhum serviço encontrado'))
                    : ListView.builder(
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final s = _services[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(s['name'] ?? 'Serviço'),
                              subtitle: Text(
                                (s['description'] ?? '') +
                                    '\nValor: R\$ ${s['price'] ?? '--'}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () => _createBooking(
                                  Map<String, dynamic>.from(s)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
