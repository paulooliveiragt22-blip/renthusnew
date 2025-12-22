// lib/screens/job_details_page.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../widgets/renthus_center_message.dart';

// ✅ bottom bar
import 'provider_job_details/job_bottom_bar.dart';

// ✅ values section
import 'provider_job_details/job_values_section.dart';

class JobDetailsPage extends StatefulWidget {
  final String jobId;

  const JobDetailsPage({super.key, required this.jobId});

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? job;

  // fotos parseadas
  List<String> _photoUrls = [];
  List<String> _photoThumbs = [];

  // veio da accepted (tem job_code/endereço/valor etc)
  bool _isAssigned = false;

  // envio de proposta
  bool _isSendingQuote = false;

  // --------- valores (JobValuesSection)
  final NumberFormat _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  // (mantido por compatibilidade com a seção)
  String _priceChoice = 'counter';
  final TextEditingController _counterPriceController = TextEditingController();
  bool _counterConfirmed = false;
  double? _counterNet;

  @override
  void dispose() {
    _counterPriceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadJobFromView();
  }

  void _showMessage(String text) {
    RenthusCenterMessage.show(context, text);
  }

  // ------------------------------------------------------------
  // LOAD (TENTA ACCEPTED, SENÃO PUBLIC)
  // ------------------------------------------------------------
  Future<void> _loadJobFromView() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      job = null;
      _photoUrls = [];
      _photoThumbs = [];
      _isAssigned = false;

      _counterConfirmed = false;
      _counterNet = null;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Usuário não autenticado.';
      });
      return;
    }

    try {
      // 1) accepted (depois do match)
      final acceptedRes =
          await supabase.from('v_provider_jobs_accepted').select('''
            id,
            job_code,
            client_id,
            provider_id,
            service_type_id,
            category_id,
            title,
            description,
            service_detected,
            status,
            amount_provider,
            street,
            number,
            district,
            city,
            state,
            zipcode,
            lat,
            lng,
            created_at,
            updated_at,
            photos
          ''').eq('id', widget.jobId).maybeSingle();

      if (acceptedRes != null) {
        final m = Map<String, dynamic>.from(acceptedRes as Map);
        final parsed = _parsePhotos(m['photos']);
        _photoUrls = parsed.urls;
        _photoThumbs = parsed.thumbs;

        setState(() {
          job = m;
          _isAssigned = true;
          isLoading = false;
        });
        return;
      }

      // 2) public (antes do match)
      final publicRes = await supabase.from('v_provider_jobs_public').select('''
        id,
        client_id,
        service_type_id,
        category_id,
        title,
        description,
        service_detected,
        status,
        city,
        state,
        lat,
        lng,
        created_at,
        photos
      ''').eq('id', widget.jobId).maybeSingle();

      if (publicRes == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Serviço não encontrado.';
        });
        return;
      }

      final m = Map<String, dynamic>.from(publicRes as Map);
      final parsed = _parsePhotos(m['photos']);
      _photoUrls = parsed.urls;
      _photoThumbs = parsed.thumbs;

      setState(() {
        job = m;
        _isAssigned = false;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar job: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Erro ao carregar detalhes.';
      });
    }
  }

  // ------------------------------------------------------------
  // ENVIAR PROPOSTA (RPC submit_job_quote ✅)
  // ------------------------------------------------------------
  double? _parseBrMoney(String s) {
    final cleaned =
        s.trim().replaceAll('R\$', '').replaceAll(RegExp(r'[^0-9,\.]'), '');

    if (cleaned.isEmpty) return null;

    // normaliza pt-BR
    final normalized = cleaned.contains(',')
        ? cleaned.replaceAll('.', '').replaceAll(',', '.')
        : cleaned;

    return double.tryParse(normalized);
  }

  double _netFromPrice(double price) {
    const fee = 0.15;
    return price * (1 - fee);
  }

  double? _getOfferedPrice(Map<String, dynamic> j) {
    final v = (j['price'] as num?)?.toDouble() ??
        (j['daily_total'] as num?)?.toDouble() ??
        (j['client_budget'] as num?)?.toDouble();
    return v;
  }

  Future<void> _sendQuote() async {
    if (_isSendingQuote) return;
    final j = job;
    if (j == null) return;

    // status permitido
    final status = (j['status'] as String?) ?? '';
    if (status != 'waiting_providers') {
      _showMessage('Este serviço não está mais disponível para proposta.');
      return;
    }

    // ✅ agora seu layout sempre usa contra proposta (counter),
    // mas deixei a lógica defensiva.
    final offered = _getOfferedPrice(j);

    double? chosenPrice;

    if (_priceChoice == 'accept') {
      if (offered == null || offered <= 0) {
        _showMessage('Este pedido não tem valor ofertado pelo cliente.');
        return;
      }
      chosenPrice = offered;
    } else {
      if (!_counterConfirmed) {
        _showMessage('Confirme o valor da proposta.');
        return;
      }
      final parsed = _parseBrMoney(_counterPriceController.text);
      if (parsed == null || parsed <= 0) {
        _showMessage('Informe um valor válido.');
        return;
      }
      chosenPrice = parsed;
    }

    setState(() => _isSendingQuote = true);

    try {
      // ✅ RPC correta (não usa status='candidate')
      await supabase.rpc('submit_job_quote', params: {
        'p_job_id': widget.jobId,
        'p_approximate_price': chosenPrice,
        'p_message': null,
      });

      if (!mounted) return;
      _showMessage('Proposta enviada! Aguarde o cliente analisar.');

      await _loadJobFromView();
    } catch (e) {
      debugPrint('Erro ao enviar proposta: $e');
      if (!mounted) return;
      _showMessage('Não foi possível enviar a proposta.');
    } finally {
      if (mounted) setState(() => _isSendingQuote = false);
    }
  }

  void _onChangePriceChoice(String v) {
    setState(() => _priceChoice = v);
  }

  void _onConfirmCounter() {
    final parsed = _parseBrMoney(_counterPriceController.text);
    if (parsed == null || parsed <= 0) {
      _showMessage('Informe um valor válido.');
      return;
    }
    setState(() {
      _counterConfirmed = true;
      _counterNet = _netFromPrice(parsed);
    });
  }

  void _onCounterTextChanged() {
    setState(() {
      _counterConfirmed = false;
      _counterNet = null;
    });
  }

  // ------------------------------------------------------------
  // PARSE PHOTOS
  // ------------------------------------------------------------
  _ParsedPhotos _parsePhotos(dynamic photosJson) {
    final urls = <String>[];
    final thumbs = <String>[];

    if (photosJson == null) return _ParsedPhotos(urls: urls, thumbs: thumbs);

    if (photosJson is List) {
      for (final item in photosJson) {
        if (item is String) {
          if (item.trim().isNotEmpty) {
            urls.add(item);
            thumbs.add(item);
          }
          continue;
        }
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final url = (map['url'] ?? map['public_url'] ?? map['full_url'])
              ?.toString()
              .trim();
          final thumb =
              (map['thumb_url'] ?? map['thumb'] ?? map['thumbnail_url'])
                  ?.toString()
                  .trim();

          if (url != null && url.isNotEmpty) {
            urls.add(url);
            thumbs.add((thumb != null && thumb.isNotEmpty) ? thumb : url);
          }
        }
      }
    } else if (photosJson is Map) {
      final map = Map<String, dynamic>.from(photosJson);
      final url = (map['url'] ?? map['public_url'] ?? map['full_url'])
          ?.toString()
          .trim();
      final thumb = (map['thumb_url'] ?? map['thumb'] ?? map['thumbnail_url'])
          ?.toString()
          .trim();

      if (url != null && url.isNotEmpty) {
        urls.add(url);
        thumbs.add((thumb != null && thumb.isNotEmpty) ? thumb : url);
      }
    }

    return _ParsedPhotos(urls: urls, thumbs: thumbs);
  }

  // ------------------------------------------------------------
  // DISTÂNCIA / MAPAS
  // ------------------------------------------------------------
  double _deg2rad(double deg) => deg * (pi / 180);

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lat2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  Future<void> _showDistanceOnly({
    required double destLat,
    required double destLng,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Ative o GPS para ver a distância.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Permissão de localização negada.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final km = _distanceKm(pos.latitude, pos.longitude, destLat, destLng);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Distância até o serviço'),
          content: Text('${km.toStringAsFixed(1)} km de você'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      _showMessage('Não foi possível calcular a distância.');
    }
  }

  Future<void> _openOnMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (!await canLaunchUrlString(url)) {
      _showMessage('Não foi possível abrir o aplicativo de mapas.');
      return;
    }
    await launchUrlString(url);
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'waiting_providers':
        return 'Disponível';
      case 'accepted':
        return 'Aceito';
      case 'on_the_way':
        return 'A caminho';
      case 'in_progress':
        return 'Em execução';
      case 'completed':
        return 'Finalizado';
      default:
        return s.isEmpty ? 'Indefinido' : s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'waiting_providers':
        return Colors.blueGrey;
      case 'accepted':
      case 'on_the_way':
      case 'in_progress':
        return const Color(0xFF34A853);
      case 'completed':
        return const Color(0xFF3B246B);
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentJob = job;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Detalhes do pedido',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _loadJobFromView,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // ✅ bottom bar só depois do match
      bottomNavigationBar: (currentJob != null && _isAssigned)
          ? JobBottomBar(
              job: currentJob,
              isAssigned: true,
              isCandidate: false,
              isChangingStatus: false,
              hasOpenDispute: false,
              canAcceptBeforeMatch: false,
              onRejectJob: () => _showMessage('Ação não usada aqui.'),
              onAcceptBeforeMatch: () => _showMessage('Ação não usada aqui.'),
              onSetOnTheWay: () => _showMessage('Implementar: on_the_way'),
              onSetInProgress: () => _showMessage('Implementar: in_progress'),
              onSetCompleted: () => _showMessage('Implementar: completed'),
              onOpenChat: () => _showMessage('Implementar: abrir chat'),
              onOpenDispute: null,
              onCancelAfterMatch: null,
            )
          : null,

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildContent(currentJob!),
    );
  }

  Widget _buildContent(Map<String, dynamic> j) {
    final title = (j['title'] as String?)?.trim() ?? 'Serviço';
    final desc = (j['description'] as String?)?.trim() ?? '';
    final serviceDetected = (j['service_detected'] as String?)?.trim() ?? '';
    final status = (j['status'] as String?)?.trim() ?? '';
    final city = (j['city'] as String?)?.trim() ?? 'Sorriso';
    final uf = (j['state'] as String?)?.trim() ?? 'MT';
    final createdAt = _fmtDate(j['created_at']);

    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();

    final statusColor = _statusColor(status);

    // valores (mantidos por compatibilidade)
    final offeredPrice = _getOfferedPrice(j);
    final priceText = (offeredPrice != null && offeredPrice > 0)
        ? _currencyBr.format(offeredPrice)
        : '—';
    final netIfAcceptText = (offeredPrice != null && offeredPrice > 0)
        ? _currencyBr.format(_netFromPrice(offeredPrice))
        : '—';

    final selectedNetPrice =
        (_priceChoice == 'accept' && offeredPrice != null && offeredPrice > 0)
            ? _netFromPrice(offeredPrice)
            : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3B246B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (serviceDetected.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    serviceDetected,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Criado em: $createdAt',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (_isAssigned) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Pedido: ${(j['job_code'] as String?)?.trim() ?? '-'}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B246B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Descrição
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descrição do cliente',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  desc.isNotEmpty ? desc : 'Sem descrição.',
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Fotos
          _buildPhotosSection(),

          const SizedBox(height: 12),

          // Local
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Local',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '$city - $uf',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (lat == null || lng == null)
                            ? null
                            : () =>
                                _showDistanceOnly(destLat: lat, destLng: lng),
                        icon: const Icon(Icons.place_outlined),
                        label: const Text('Ver distância'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (lat == null || lng == null)
                            ? null
                            : () => _openOnMap(lat, lng),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Abrir no mapa'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  (lat == null || lng == null)
                      ? 'Este pedido não possui localização (lat/lng).'
                      : 'Localização baseada nas coordenadas do pedido.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------------
          // ✅ VALORES (somente antes do match)
          // ------------------------------------------------------------
          if (!_isAssigned) ...[
            const SizedBox(height: 14),
            JobValuesSection(
              isAssigned: _isAssigned,
              isCandidate: false,
              currencyBr: _currencyBr,
              offeredPrice: offeredPrice,
              priceText: priceText,
              netIfAcceptText: netIfAcceptText,
              lastQuotePrice: null,
              quoteNet: null,
              hasQuote: false,
              priceChoice: _priceChoice,
              counterPriceController: _counterPriceController,
              counterConfirmed: _counterConfirmed,
              counterNet: _counterNet,
              selectedNetPrice: selectedNetPrice,
              onChangePriceChoice: _onChangePriceChoice,
              onConfirmCounter: _onConfirmCounter,
              onCounterTextChanged: _onCounterTextChanged,
            ),
          ],

          // ------------------------------------------------------------
          // ✅ BOTÃO FINAL: ENVIAR PROPOSTA
          // ------------------------------------------------------------
          const SizedBox(height: 18),
          if (!_isAssigned && status == 'waiting_providers') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSendingQuote ? null : _sendQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0DAA00),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Text(
                  _isSendingQuote ? 'Enviando...' : 'Enviar proposta',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Você será notificado quando o cliente aceitar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fotos (${_photoUrls.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_photoUrls.isEmpty)
            const Text(
              'Nenhuma foto anexada.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final fullUrl = _photoUrls[index];
                  final thumbUrl = (index < _photoThumbs.length)
                      ? _photoThumbs[index]
                      : fullUrl;

                  return GestureDetector(
                    onTap: () => _openFullImage(fullUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFullImage(String url) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(imageUrl: url),
      ),
    );
  }
}

class _ParsedPhotos {
  final List<String> urls;
  final List<String> thumbs;

  _ParsedPhotos({required this.urls, required this.thumbs});
}

class _FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white70,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
