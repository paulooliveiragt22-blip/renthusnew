// lib/screens/services_catalog_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServicesCatalogScreen extends StatefulWidget {
  const ServicesCatalogScreen({super.key});
  @override
  State<ServicesCatalogScreen> createState() => _ServicesCatalogScreenState();
}

class _ServicesCatalogScreenState extends State<ServicesCatalogScreen> {
  final _client = Supabase.instance.client;
  List<dynamic> _services = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices([String? q]) async {
    setState(() => _loading = true);
    var builder = _client.from('services_catalog').select('*, service_categories(name)');
    if (q != null && q.isNotEmpty) builder = builder.ilike('name', '%${q}%');
    final res = await builder.order('name');
    setState(() {
      _services = res ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar serviço'),
              onChanged: (v) {
                _query = v;
                _loadServices(v);
              },
            ),
          ),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _services.length,
              itemBuilder: (_, i) {
                final s = _services[i];
                return ListTile(
                  title: Text(s['name']),
                  subtitle: Text('Categoria: ${s['service_categories']?['name'] ?? '—'}\nPreço: ${s['price'] ?? '—'}'),
                  onTap: () => Navigator.pushNamed(context, '/service_detail', arguments: s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
