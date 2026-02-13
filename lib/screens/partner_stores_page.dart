import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

import 'partner_store_details_page.dart';

class PartnerStoresPage extends ConsumerStatefulWidget {
  const PartnerStoresPage({super.key});

  @override
  ConsumerState<PartnerStoresPage> createState() => _PartnerStoresPageState();
}

class _PartnerStoresPageState extends ConsumerState<PartnerStoresPage> {

  bool _loading = true;
  List<Map<String, dynamic>> _stores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase
          .from('partner_stores')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      setState(() {
        _stores = List<Map<String, dynamic>>.from(res as List<dynamic>);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar lojas parceiras: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lojas parceiras'),
        backgroundColor: roxo,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF2F2F2),
      body: RefreshIndicator(
        onRefresh: _loadStores,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stores.isEmpty
                ? const Center(
                    child: Text(
                      'Em breve você verá aqui lojas parceiras\ncom produtos e vantagens pra você.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stores.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      final cover = store['cover_image_url'] as String?;
                      final city = store['city'] as String?;
                      final uf = store['state'] as String?;
                      final subtitle = [city, uf]
                          .where((e) => (e ?? '').isNotEmpty)
                          .join(' - ');

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PartnerStoreDetailsPage(store: store),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: cover != null && cover.isNotEmpty
                                    ? Image.network(
                                        cover,
                                        width: double.infinity,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: double.infinity,
                                        height: 150,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.storefront,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            store['name'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: roxo,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (store['short_description'] !=
                                                  null &&
                                              (store['short_description']
                                                      as String)
                                                  .isNotEmpty)
                                            Text(
                                              store['short_description'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          if (subtitle.isNotEmpty)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 14,
                                                  color: Colors.black54,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    subtitle,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roxo.withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Parceiro',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: roxo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
