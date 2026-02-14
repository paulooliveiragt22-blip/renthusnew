// lib/screens/services_catalog_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';

class ServicesCatalogScreen extends ConsumerStatefulWidget {
  const ServicesCatalogScreen({super.key});
  @override
  ConsumerState<ServicesCatalogScreen> createState() => _ServicesCatalogScreenState();
}

class _ServicesCatalogScreenState extends ConsumerState<ServicesCatalogScreen> {
  List<dynamic> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices([String? q]) async {
    setState(() => _loading = true);
    final client = ref.read(supabaseProvider);
    var builder = client.from('services_catalog').select('*, service_categories(name)');
    if (q != null && q.isNotEmpty) builder = builder.ilike('name', '%$q%');
    final res = await builder.order('name');
    setState(() {
      _services = List<dynamic>.from(res as List);
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
              onChanged: (v) => _loadServices(v),
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
                  onTap: () {
                    final id = s['id']?.toString();
                    if (id != null && id.isNotEmpty) {
                      context.go('${AppRoutes.serviceDetail}/$id');
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
