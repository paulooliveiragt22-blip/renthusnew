// lib/screens/service_details_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({super.key});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _service;
  String? _categoryName;
  Map<String, dynamic>? _provider;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0.0;

  // imagens
  List<String> _imageUrls = [];
  int _currentImageIndex = 0;
  bool _imagesLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromArgs());
  }

  void _initFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final serviceId = args?['serviceId'] as String?;
    if (serviceId == null || serviceId.isEmpty) {
      setState(() {
        _error = 'ID do serviço ausente.';
        _loading = false;
      });
      return;
    }
    _loadAll(serviceId);
  }

  Future<void> _loadAll(String serviceId) async {
    setState(() {
      _loading = true;
      _error = null;
      _service = null;
      _categoryName = null;
      _provider = null;
      _reviews = [];
      _avgRating = 0.0;
      _imageUrls = [];
      _currentImageIndex = 0;
    });

    try {
      // 1) Busca serviço
      final svc = await _client
          .from('services_catalog')
          .select('id, unit, categoria_id, dispute_hours, created_at, update_at, provider_id, image_urls, image_url')
          .eq('id', serviceId)
          .maybeSingle();

      if (svc == null) {
        setState(() {
          _error = 'Serviço não encontrado.';
          _loading = false;
        });
        return;
      }

      final Map<String, dynamic> serviceMap = Map<String, dynamic>.from(svc as Map);
      setState(() => _service = serviceMap);

      // 2) Categoria
      final catId = serviceMap['categoria_id'];
      if (catId != null && catId.toString().isNotEmpty) {
        try {
          final cat = await _client.from('service_categories').select('id, name').eq('id', catId).maybeSingle();
          if (cat != null && cat is Map<String, dynamic>) {
            setState(() => _categoryName = (cat['name'] ?? '').toString());
          }
        } catch (_) {}
      }

      // 3) Provider (opcional)
      final provId = serviceMap['provider_id'];
      if (provId != null && provId.toString().isNotEmpty) {
        try {
          final p = await _client.from('profiles').select('id, name, phone, avatar_url').eq('id', provId).maybeSingle();
          if (p != null && p is Map<String, dynamic>) setState(() => _provider = Map<String, dynamic>.from(p));
        } catch (_) {}
      }

      // 4) Reviews (opcional)
      try {
        final revs = await _client
            .from('reviews')
            .select('id, rating, comment, created_at, author:author_id(name)')
            .eq('service_id', serviceMap['id'])
            .order('created_at', ascending: false);
        if (revs != null && revs is List) {
          final list = List<Map<String, dynamic>>.from(revs.map((e) => Map<String, dynamic>.from(e)));
          setState(() => _reviews = list);
          if (list.isNotEmpty) {
            final sum = list.fold<double>(0.0, (prev, el) {
              final r = double.tryParse((el['rating'] ?? '0').toString()) ?? 0.0;
              return prev + r;
            });
            setState(() => _avgRating = (sum / list.length));
          }
        }
      } catch (_) {
        // ignora se não existir
      }

      // 5) Imagens - tentativa por campos do registro
      await _attemptLoadImagesFromRecord(serviceMap);
      // 6) Se nenhuma imagem obtida, tenta listar no bucket 'service-attachments' sob pasta '<serviceId>/'
      if (_imageUrls.isEmpty) {
        await _attemptLoadImagesFromStorageFolder(serviceMap['id']?.toString() ?? '');
      }
    } catch (e, st) {
      debugPrint('Erro carregando detalhes: $e\n$st');
      setState(() {
        _error = 'Erro ao carregar detalhes: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _attemptLoadImagesFromRecord(Map<String, dynamic> serviceMap) async {
    try {
      // 1) image_urls como lista de strings
      final dynamic imageUrlsRaw = serviceMap['image_urls'];
      if (imageUrlsRaw != null) {
        if (imageUrlsRaw is List) {
          final list = imageUrlsRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          if (list.isNotEmpty) {
            setState(() => _imageUrls = List<String>.from(list));
            return;
          }
        } else if (imageUrlsRaw is String) {
          // pode ser JSON string ou single URL separado por vírgula — tratamos como single URL
          final s = imageUrlsRaw.toString();
          if (s.isNotEmpty) {
            setState(() => _imageUrls = [s]);
            return;
          }
        }
      }

      // 2) image_url singular
      final dynamic single = serviceMap['image_url'];
      if (single != null && single.toString().isNotEmpty) {
        setState(() => _imageUrls = [single.toString()]);
        return;
      }
    } catch (e) {
      debugPrint('Erro ao extrair image_urls do registro: $e');
    }
  }

  Future<void> _attemptLoadImagesFromStorageFolder(String serviceId) async {
    if (serviceId.isEmpty) return;
    setState(() => _imagesLoading = true);
    try {
      final bucket = 'service-attachments';
      // Tenta listar arquivos em 'serviceId/' (algumas instalações usam essa organização)
      List<dynamic>? files;
      try {
        final res = await _client.storage.from(bucket).list(path: '$serviceId/', limit: 100);
        // resultado pode ser `List` ou Map dependendo da versão; normaliza:
        if (res != null && res is List) {
          files = res;
        } else if (res != null && res is Map && res.containsKey('data')) {
          files = res['data'] as List<dynamic>?;
        }
      } catch (e) {
        debugPrint('storage.list erro: $e');
        files = null;
      }

      if (files != null && files.isNotEmpty) {
        final List<String> urls = [];
        for (final f in files) {
          try {
            final String path = (f is Map && f['name'] != null) ? '${serviceId}/${f['name']}' : f.toString();
            // tenta gerar public url (se bucket público)
            try {
              final publicRes = _client.storage.from(bucket).getPublicUrl(path);
              // getPublicUrl pode retornar Map { 'publicUrl': '...' } ou um object depending on lib version
              if (publicRes != null) {
                if (publicRes is String) {
                  urls.add(publicRes);
                } else if (publicRes is Map && publicRes.containsKey('publicUrl')) {
                  urls.add(publicRes['publicUrl'].toString());
                } else if (publicRes is PostgrestResponse && publicRes.data != null) {
                  final data = publicRes.data;
                  if (data is Map && data['publicUrl'] != null) urls.add(data['publicUrl'].toString());
                }
              }
            } catch (e) {
              // se getPublicUrl falhar (bucket privado), tenta signed url
              try {
                final signed = await _client.storage.from(bucket).createSignedUrl(path, 60); // 60s
                if (signed != null) {
                  if (signed is String) urls.add(signed);
                  else if (signed is Map && signed['signedURL'] != null) urls.add(signed['signedURL'].toString());
                  else if (signed is PostgrestResponse && signed.data != null) {
                    final d = signed.data;
                    if (d is Map && d['signedURL'] != null) urls.add(d['signedURL'].toString());
                  }
                }
              } catch (e2) {
                debugPrint('Erro ao gerar signed URL: $e2');
              }
            }
          } catch (e) {
            debugPrint('Erro processando arquivo storage entry: $e');
          }
        }
        if (urls.isNotEmpty) {
          setState(() => _imageUrls = urls);
          return;
        }
      }
    } catch (e) {
      debugPrint('Erro listando storage: $e');
    } finally {
      setState(() => _imagesLoading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  Widget _buildHeader() {
    final title = _service?['unit']?.toString() ?? 'Serviço';
    final dispute = _service?['dispute_hours']?.toString() ?? '-';
    final created = _formatDate(_service?['created_at']?.toString());
    final updated = _formatDate(_service?['update_at']?.toString());

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(children: [
        if (_categoryName != null) Chip(label: Text(_categoryName!)) else const SizedBox.shrink(),
        const SizedBox(width: 8),
        Chip(label: Text('Duração: $dispute h')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 6),
        Text(_reviews.isEmpty ? 'Sem avaliações' : '${_avgRating.toStringAsFixed(1)} (${_reviews.length})'),
      ]),
      const SizedBox(height: 8),
      Text('Criado em: $created'),
      const SizedBox(height: 2),
      Text('Atualizado: $updated'),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildProviderCard() {
    if (_provider == null) return const SizedBox.shrink();
    final name = _provider!['name']?.toString() ?? '-';
    final phone = _provider!['phone']?.toString() ?? '-';
    final avatar = _provider!['avatar_url']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: avatar != null && avatar.isNotEmpty
            ? CircleAvatar(backgroundImage: NetworkImage(avatar))
            : CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
        title: Text(name),
        subtitle: Text('Contato: $phone'),
        trailing: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contato com prestador (implementar)')));
          },
          child: const Text('Contato'),
        ),
      ),
    );
  }

  Widget _buildReviews() {
    if (_reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Ainda não há avaliações para este serviço.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _reviews.map((r) {
        final rating = double.tryParse((r['rating'] ?? '0').toString()) ?? 0.0;
        final comment = r['comment']?.toString() ?? '';
        final created = _formatDate(r['created_at']?.toString());
        final author = (r['author'] is Map && r['author']['name'] != null) ? r['author']['name'].toString() : 'Usuário';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(author.isNotEmpty ? author[0].toUpperCase() : '?')),
            title: Row(children: [
              Text(author),
              const SizedBox(width: 8),
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1)),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (comment.isNotEmpty) Text(comment),
              const SizedBox(height: 6),
              Text(created, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // GALERIA UI
  Widget _buildGallery() {
    if (_imagesLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    if (_imageUrls.isEmpty) {
      // fallback visual
      final title = (_service?['unit']?.toString() ?? '-');
      return SizedBox(
        height: 200,
        child: Center(
          child: CircleAvatar(
            radius: 54,
            child: Text(title.isNotEmpty ? title[0].toUpperCase() : '?', style: const TextStyle(fontSize: 36)),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            itemCount: _imageUrls.length,
            controller: PageController(initialPage: _currentImageIndex),
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, idx) {
              final url = _imageUrls[idx];
              return GestureDetector(
                onTap: () => _openFullScreenImage(idx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, fit: BoxFit.cover, width: double.infinity, loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    }, errorBuilder: (ctx, err, st) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image, size: 48)),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _imageUrls.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (ctx, i) {
              final thumb = _imageUrls[i];
              return GestureDetector(
                onTap: () => setState(() => _currentImageIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(color: i == _currentImageIndex ? Colors.blueAccent : Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openFullScreenImage(int idx) async {
    if (idx < 0 || idx >= _imageUrls.length) return;
    final url = _imageUrls[idx];
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Stack(children: [
          InteractiveViewer(child: Image.network(url, fit: BoxFit.contain, width: double.infinity, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
        ]),
      ),
    );
  }

  void _onTapAgendar() {
    final id = _service?['id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID do serviço inválido')));
      return;
    }
    Navigator.pushNamed(context, '/booking_details', arguments: {'serviceId': id});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Serviço')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _error != null
            ? Center(child: Text(_error!))
            : SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildGallery(),
                  const SizedBox(height: 12),
                  if (_service != null) _buildHeader(),
                  _buildProviderCard(),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text('Avaliações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildReviews(),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onTapAgendar,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Agendar este serviço'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}
