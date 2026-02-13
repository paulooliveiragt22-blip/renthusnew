import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

const kRoxo = Color(0xFF3B246B);

class ProviderServicesPage extends ConsumerStatefulWidget {

  const ProviderServicesPage({
    super.key,
    this.providerId,
  });
  final String? providerId;

  @override
  ConsumerState<ProviderServicesPage> createState() => _ProviderServicesPageState();
}

class _ProviderServicesPageState extends ConsumerState<ProviderServicesPage> {
  bool _loadingServices = true;
  List<_ProviderCategoryItem> _serviceItems = [];

  @override
  void initState() {
    super.initState();
    _loadMyServicesFromView();
  }

  void _comingSoon([String msg = 'Em breve.']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadMyServicesFromView() async {
    setState(() => _loadingServices = true);

    try {
      final supabase = ref.read(supabaseProvider);
      String? providerId = widget.providerId;

      if (providerId == null || providerId.isEmpty) {
        final me = await supabase
            .from('v_provider_me')
            .select('provider_id')
            .maybeSingle();
        if (me != null) {
          final m = Map<String, dynamic>.from(me as Map);
          providerId = m['provider_id']?.toString();
        }
      }

      if (providerId == null) {
        if (!mounted) return;
        setState(() {
          _serviceItems = [];
          _loadingServices = false;
        });
        return;
      }

      final rows = await supabase
          .from('v_public_provider_services')
          .select('provider_id, service_type_name')
          .eq('provider_id', providerId);

      final items = <_ProviderCategoryItem>[];

      for (final r in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(r as Map);
        final name = (m['service_type_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        items.add(
          _ProviderCategoryItem(categoryName: 'Serviço', serviceName: name),
        );
      }

      items.sort((a, b) => a.serviceName.compareTo(b.serviceName));

      if (!mounted) return;
      setState(() {
        _serviceItems = items;
        _loadingServices = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar v_public_provider_services: $e');
      if (!mounted) return;
      setState(() => _loadingServices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: const Text('Minhas categorias e serviços'),
        backgroundColor: kRoxo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyServicesFromView,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.build_circle_outlined,
                          color: kRoxo,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Serviços atendidos',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _comingSoon(
                            'Edição de serviços será habilitada em breve.',
                          ),
                          child: const Text('Editar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingServices)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_serviceItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 6),
                        child: Text(
                          'Você ainda não selecionou serviços. Toque em "Editar" para configurar.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _serviceItems
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle,
                                        size: 14, color: kRoxo,),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.serviceName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCategoryItem {

  _ProviderCategoryItem({
    required this.categoryName,
    required this.serviceName,
  });
  final String categoryName;
  final String serviceName;
}
