import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class PartnerStoreDetailsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> store;

  const PartnerStoreDetailsPage({
    super.key,
    required this.store,
  });

  @override
  ConsumerState<PartnerStoreDetailsPage> createState() =>
      _PartnerStoreDetailsPageState();
}

class _PartnerStoreDetailsPageState extends ConsumerState<PartnerStoreDetailsPage> {

  bool _loadingProducts = true;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase
          .from('partner_store_products')
          .select()
          .eq('store_id', widget.store['id'])
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);

      setState(() {
        _products = List<Map<String, dynamic>>.from(res as List<dynamic>);
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar produtos: $e')),
      );
    }
  }

  Future<void> _openOnMaps() async {
    final address = widget.store['address'] as String?;
    final city = widget.store['city'] as String?;
    final state = widget.store['state'] as String?;

    String query = '';
    if ((address ?? '').isNotEmpty) {
      query = address!;
    }
    final tail = [city, state].where((e) => (e ?? '').isNotEmpty).join(' - ');
    if (tail.isNotEmpty) {
      query = query.isEmpty ? tail : '$query, $tail';
    }

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Endereço não disponível para esta loja.'),
        ),
      );
      return;
    }

    final encoded = Uri.encodeComponent(query);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encoded';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o mapa.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);
    const laranja = Color(0xFFFF6600);

    final store = widget.store;
    final cover = store['cover_image_url'] as String?;
    final address = store['address'] as String?;
    final city = store['city'] as String?;
    final state = store['state'] as String?;
    final location = [
      address,
      [city, state].where((e) => (e ?? '').isNotEmpty).join(' - ')
    ].where((e) => (e ?? '').isNotEmpty).join('\n');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: Text(store['name'] ?? 'Loja parceira'),
        backgroundColor: roxo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Capa
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: cover != null && cover.isNotEmpty
                            ? Image.network(
                                cover,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.storefront,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Parceiro Renthus',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: roxo,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (store['short_description'] != null &&
                          (store['short_description'] as String).isNotEmpty)
                        Text(
                          store['short_description'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (location.isNotEmpty) ...[
                        const Text(
                          'Endereço',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: roxo,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _openOnMaps,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Ver no mapa'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: roxo,
                            side: const BorderSide(color: roxo),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        'Produtos em destaque',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: laranja,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_loadingProducts)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_products.isEmpty)
                        const Text(
                          'Em breve você verá produtos desta loja aqui.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        )
                      else
                        Column(
                          children: _products.map((p) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: p['image_url'] != null &&
                                        (p['image_url'] as String).isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          p['image_url'],
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.shopping_bag_outlined),
                                title: Text(
                                  p['name'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: p['description'] != null
                                    ? Text(
                                        p['description'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      )
                                    : null,
                                trailing: p['price'] != null
                                    ? Text(
                                        'R\$ ${(p['price'] as num).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: roxo,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
