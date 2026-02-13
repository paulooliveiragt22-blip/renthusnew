import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/screens/provider_job_details/job_bottom_bar.dart';
import 'package:renthus/screens/provider_job_details/job_values_section.dart';
import 'package:renthus/widgets/renthus_center_message.dart';

class JobDetailsPage extends ConsumerStatefulWidget {

  const JobDetailsPage({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends ConsumerState<JobDetailsPage> {
  final _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );
  final _counterPriceController = TextEditingController();
  String _priceChoice = 'counter';
  bool _counterConfirmed = false;
  double? _counterNet;
  bool _isSendingQuote = false;

  @override
  void dispose() {
    _counterPriceController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    RenthusCenterMessage.show(context, text);
  }

  double? _parseBrMoney(String s) {
    final cleaned =
        s.trim().replaceAll('R\$', '').replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (cleaned.isEmpty) return null;
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

  double _deg2rad(double deg) => deg * (pi / 180);

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  Future<void> _showDistanceOnly({required double destLat, required double destLng}) async {
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

  Future<void> _sendQuote() async {
    if (_isSendingQuote) return;
    final jobAsync = ref.read(providerJobByIdProvider(widget.jobId));
    final j = jobAsync.valueOrNull;
    if (j == null) return;

    final status = (j['status'] as String?) ?? '';
    if (status != 'waiting_providers') {
      _showMessage('Este serviço não está mais disponível para proposta.');
      return;
    }

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
      final repo = ref.read(appJobRepositoryProvider);
      await repo.submitJobQuote(
        jobId: widget.jobId,
        approximatePrice: chosenPrice,
        message: null,
      );

      if (!mounted) return;
      _showMessage('Proposta enviada! Aguarde o cliente analisar.');

      ref.invalidate(providerJobByIdProvider(widget.jobId));
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

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(providerJobByIdProvider(widget.jobId));

    return jobAsync.when(
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B246B),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Detalhes do pedido',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B246B),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Detalhes do pedido',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (job) {
        if (job == null) {
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
            ),
            body: const Center(
              child: Text('Serviço não encontrado.'),
            ),
          );
        }

        final parsed = _parsePhotos(job['photos']);
        final isAssigned = job['job_code'] != null;

        final offeredPrice = _getOfferedPrice(job);
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

        final status = (job['status'] as String?) ?? '';

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
                onPressed: () =>
                    ref.invalidate(providerJobByIdProvider(widget.jobId)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          bottomNavigationBar: (isAssigned)
              ? JobBottomBar(
                  job: job,
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
          body: _buildContent(
            job,
            isAssigned,
            offeredPrice,
            priceText,
            netIfAcceptText,
            selectedNetPrice,
            status,
            parsed.urls,
            parsed.thumbs,
          ),
        );
      },
    );
  }

  Widget _buildContent(
    Map<String, dynamic> j,
    bool isAssigned,
    double? offeredPrice,
    String priceText,
    String netIfAcceptText,
    double? selectedNetPrice,
    String status,
    List<String> photoUrls,
    List<String> photoThumbs,
  ) {
    final title = (j['title'] as String?)?.trim() ?? 'Serviço';
    final desc = (j['description'] as String?)?.trim() ?? '';
    final serviceDetected = (j['service_detected'] as String?)?.trim() ?? '';
    final city = (j['city'] as String?)?.trim() ?? 'Sorriso';
    final uf = (j['state'] as String?)?.trim() ?? 'MT';
    final createdAt = _fmtDate(j['created_at']);
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final statusColor = _statusColor(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                if (isAssigned) ...[
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
          _buildPhotosSection(photoUrls, photoThumbs),
          const SizedBox(height: 12),
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
          if (!isAssigned) ...[
            const SizedBox(height: 14),
            JobValuesSection(
              isAssigned: isAssigned,
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
          const SizedBox(height: 18),
          if (!isAssigned && status == 'waiting_providers') ...[
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

  Widget _buildPhotosSection(List<String> photoUrls, List<String> photoThumbs) {
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
            'Fotos (${photoUrls.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (photoUrls.isEmpty)
            const Text(
              'Nenhuma foto anexada.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final fullUrl = photoUrls[index];
                  final thumbUrl = (index < photoThumbs.length)
                      ? photoThumbs[index]
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

  _ParsedPhotos({required this.urls, required this.thumbs});
  final List<String> urls;
  final List<String> thumbs;
}

class _FullScreenImagePage extends StatelessWidget {

  const _FullScreenImagePage({required this.imageUrl});
  final String imageUrl;

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
