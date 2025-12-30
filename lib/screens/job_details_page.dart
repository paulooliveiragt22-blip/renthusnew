// lib/screens/job_details_page.dart
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/renthus_center_message.dart';

// ✅ bottom bar
import 'provider_job_details/job_bottom_bar.dart';

// ✅ values section
import 'provider_job_details/job_values_section.dart';

// ✅ chat
import 'chat_page.dart';
import '../repositories/chat_repository.dart';

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

  // ✅ mudar status (RPC)
  bool _isChangingStatus = false;

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

  // ✅ chat
  bool _openingChat = false;
  final _chatRepo = ChatRepository();

  // ------------------------------------------------------------
  // MAPA / LOCALIZAÇÃO DO PROVIDER
  // ------------------------------------------------------------
  GoogleMapController? _mapController;
  bool _loadingMyLocation = false;
  Position? _myPos;

  @override
  void dispose() {
    _counterPriceController.dispose();
    _mapController?.dispose();
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

  // 🔒 Fix no app: endereço completo + pin exato somente após accepted+
  bool _canSeeFullAddress(Map<String, dynamic> j) {
    final s = (j['status'] as String?)?.trim() ?? '';
    return s == 'accepted' ||
        s == 'on_the_way' ||
        s == 'in_progress' ||
        s == 'completed';
  }

  // ------------------------------------------------------------
  // LOCALIZAÇÃO ATUAL DO PROVIDER
  // ------------------------------------------------------------
  Future<Position?> _ensureMyLocation() async {
    if (_loadingMyLocation) return _myPos;

    setState(() => _loadingMyLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Ative o GPS para usar o mapa.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Permissão de localização negada.');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _myPos = pos;
      return pos;
    } catch (_) {
      _showMessage('Não foi possível obter sua localização.');
      return null;
    } finally {
      if (mounted) setState(() => _loadingMyLocation = false);
    }
  }

  Future<void> _centerMapOnMe() async {
    final pos = await _ensureMyLocation();
    if (pos == null) return;

    final c = _mapController;
    if (c == null) return;

    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // 🧭 ENDEREÇO (para abrir Maps sempre pelo mesmo texto exibido)
  // ------------------------------------------------------------
  String _str(dynamic v) => (v?.toString().trim() ?? '');
  String _dashIfEmpty(String v) => v.isEmpty ? '—' : v;

  /// Endereço para exibir (no card Local).
  /// - Se canSeeFull: rua, número, bairro, cidade/uf
  /// - Se não: cidade/uf
  String _displayAddress(Map<String, dynamic> j, {required bool canSeeFull}) {
    final city = _str(j['city']);
    final uf = _str(j['state']);

    final cityUf = [
      city.isNotEmpty ? city : '—',
      uf.isNotEmpty ? uf : '—',
    ].join(' - ');

    if (!canSeeFull) return cityUf;

    final street = _str(j['street']);
    final number = _str(j['number']);
    final district = _str(j['district']);

    final line1 = [
      street,
      number.isNotEmpty ? number : '',
    ].where((e) => e.trim().isNotEmpty).join(', ');

    final line2 = [
      district,
      cityUf,
    ].where((e) => e.trim().isNotEmpty).join(' - ');

    final full = [
      line1,
      line2,
    ].where((e) => e.trim().isNotEmpty).join(' - ');

    return full.isNotEmpty ? full : cityUf;
  }

  /// Endereço para o Google Maps (igual ao exibido no card).
  /// Obs: você pediu remover CEP do card; então não colocamos CEP também no link.
  String _mapsQueryFromLocalCard(Map<String, dynamic> j,
      {required bool canSeeFull}) {
    return _displayAddress(j, canSeeFull: canSeeFull);
  }

  // ------------------------------------------------------------
  // 📍 Abrir no Google Maps (buscar por endereço)
  // ------------------------------------------------------------
  Future<void> _openPlaceInMapsByQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _showMessage('Endereço indisponível.');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showMessage('Não foi possível abrir o Google Maps.');
  }

  // ------------------------------------------------------------
  // 🛣️ Abrir rota no Google Maps (navegação) usando o MESMO endereço exibido
  // ------------------------------------------------------------
  Future<void> _openRouteInGoogleMapsByQuery(String destinationQuery) async {
    final q = destinationQuery.trim();
    if (q.isEmpty) {
      _showMessage('Endereço indisponível.');
      return;
    }

    final pos = await _ensureMyLocation();
    final origin = (pos != null) ? '${pos.latitude},${pos.longitude}' : '';

    final uri = origin.isEmpty
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=${Uri.encodeComponent(q)}&travelmode=driving',
          );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showMessage('Não foi possível abrir o Google Maps.');
  }

  // 🚗 ETA (estimado por distância e velocidade média)
  String _etaFromKm(double km) {
    const avgKmh = 35.0; // ajuste se quiser
    final totalMinutes = ((km / avgKmh) * 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m}min';
  }

  double? _kmFromMeTo(double destLat, double destLng) {
    if (_myPos == null) return null;
    return _distanceKm(_myPos!.latitude, _myPos!.longitude, destLat, destLng);
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
      remind:
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
      photos,
      client_full_name,
      client_avatar_url
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
  // ✅ RPC: atualizar status do job (alinhado pro backend)
  // Recomendação: RPC também preencher timestamps por transição:
  // accepted_at, on_the_way_at, in_progress_at, completed_at, cancelled_at
  // e sempre updated_at.
  // ------------------------------------------------------------
  Future<void> _setJobStatus(String newStatus) async {
    if (_isChangingStatus) return;

    final j = job;
    if (j == null) return;

    if (!_isAssigned) {
      _showMessage('Ação disponível apenas após o aceite.');
      return;
    }

    setState(() => _isChangingStatus = true);

    try {
      // 🔧 RPC sugerida (vamos criar depois):
      // provider_update_job_status(p_job_id uuid, p_new_status text)
      // - valida transição
      // - garante que provider_id bate com auth.uid()
      // - atualiza jobs.status
      // - seta timestamp da etapa
      await supabase.rpc('provider_update_job_status', params: {
        'p_job_id': widget.jobId,
        'p_new_status': newStatus,
      });

      if (!mounted) return;

      // recarrega a view
      await _loadJobFromView();
      _showMessage('Status atualizado.');
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
      if (!mounted) return;
      _showMessage('Não foi possível atualizar o status.');
    } finally {
      if (mounted) setState(() => _isChangingStatus = false);
    }
  }

  // ------------------------------------------------------------
  // CHAT
  // ------------------------------------------------------------
  bool _isJobChatLocked(String status) {
    final s = status.trim();
    return s == 'completed' || s == 'cancelled';
  }

  Future<void> _openChat() async {
    if (_openingChat) return;

    final j = job;
    if (j == null) return;

    if (!_isAssigned) {
      _showMessage('O chat fica disponível após o aceite do serviço.');
      return;
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      _showMessage('Usuário não autenticado.');
      return;
    }

    final providerId = (j['provider_id'] as String?)?.trim();
    if (providerId == null || providerId.isEmpty) {
      _showMessage('Não foi possível identificar o prestador.');
      return;
    }

    final status = (j['status'] as String?) ?? '';
    final isLocked = _isJobChatLocked(status);

    setState(() => _openingChat = true);

    try {
      final conversationId = await _chatRepo.upsertConversationForJob(
        jobId: widget.jobId,
        providerId: providerId,
      );

      if (!mounted) return;

      final jobCode = (j['job_code'] as String?)?.trim() ?? '';
      final otherName = (j['client_full_name'] as String?)?.trim() ?? '';

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            currentUserId: currentUser.id,
            currentUserRole: 'provider',
            isChatLocked: isLocked,
            jobTitle: jobCode.isNotEmpty ? jobCode : 'Pedido',
            otherUserName: otherName.isNotEmpty ? otherName : 'Cliente',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao abrir chat: $e');
      if (!mounted) return;
      _showMessage('Não foi possível abrir o chat.');
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  // ------------------------------------------------------------
  // ENVIAR PROPOSTA (RPC submit_job_quote ✅)
  // ------------------------------------------------------------
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

  Future<void> _sendQuote() async {
    if (_isSendingQuote) return;
    final j = job;
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
  // DISTÂNCIA
  // ------------------------------------------------------------
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
      case 'cancelled':
        return 'Cancelado';
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
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _clientMiniRow(Map<String, dynamic> j) {
    final name = (j['client_full_name'] as String?)?.trim() ?? '';
    final avatar = (j['client_avatar_url'] as String?)?.trim() ?? '';

    if (name.isEmpty && avatar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF3B246B).withOpacity(0.10),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            onBackgroundImageError: avatar.isNotEmpty ? (_, __) {} : null,
            child: avatar.isEmpty
                ? const Icon(Icons.person, size: 18, color: Color(0xFF3B246B))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name.isNotEmpty ? name : 'Cliente',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers({
    required bool showExactJobPin,
    double? jobLat,
    double? jobLng,
  }) {
    final markers = <Marker>{};

    if (_myPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_myPos!.latitude, _myPos!.longitude),
          infoWindow: const InfoWindow(title: 'Você'),
        ),
      );
    }

    if (jobLat != null && jobLng != null && showExactJobPin) {
      markers.add(
        Marker(
          markerId: const MarkerId('job_location'),
          position: LatLng(jobLat, jobLng),
          infoWindow: const InfoWindow(title: 'Local do serviço'),
        ),
      );
    }

    return markers;
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
      bottomNavigationBar: (currentJob != null && _isAssigned)
          ? JobBottomBar(
              job: currentJob,
              isAssigned: true,
              isCandidate: false,
              isChangingStatus: _isChangingStatus,
              hasOpenDispute: false,
              canAcceptBeforeMatch: false,
              onRejectJob: () => _showMessage('Ação não usada aqui.'),
              onAcceptBeforeMatch: () => _showMessage('Ação não usada aqui.'),
              onSetOnTheWay: () => _setJobStatus('on_the_way'),
              onSetInProgress: () => _setJobStatus('in_progress'),
              onSetCompleted: () => _setJobStatus('completed'),
              onOpenChat: _openChat,
              onOpenDispute: null,
              onCancelAfterMatch: () => _setJobStatus('cancelled'),
              isOpeningChat: _openingChat,
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
    final city = (j['city'] as String?)?.trim() ?? '—';
    final uf = (j['state'] as String?)?.trim() ?? '—';
    final createdAt = _fmtDate(j['created_at']);

    final canSeeFull = _canSeeFullAddress(j);

    // campos (no public pode vir vazio — ok)
    final street = _str(j['street']);
    final number = _str(j['number']);
    final district = _str(j['district']);

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

    // ✅ remove duplicidade do topo:
    // se service_detected for igual ao title (ex.: "Pedreiro"), não mostramos.
    final showServiceDetected = serviceDetected.isNotEmpty &&
        serviceDetected.toLowerCase() != title.toLowerCase();

    // ✅ endereço que aparece em "Local" (e que será usado para Maps/Rota)
    final localAddressDisplay = _displayAddress(j, canSeeFull: canSeeFull);
    final mapsQuery = _mapsQueryFromLocalCard(j, canSeeFull: canSeeFull);

    final showDistanceButton = status == 'waiting_providers';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (card do topo)
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
                if (_isAssigned) _clientMiniRow(j),
                if (showServiceDetected) ...[
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

          // Local (mapa clicável + rota abre maps com o mesmo endereço exibido)
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Local',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (!canSeeFull)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Endereço após aceite',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // ✅ sempre mostra a cidade/UF (vem de v_provider_jobs_accepted.city também)
                Text(
                  '$city - $uf',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                if (canSeeFull) ...[
                  _infoLine(label: 'Rua', value: _dashIfEmpty(street)),
                  _infoLine(label: 'Número', value: _dashIfEmpty(number)),
                  _infoLine(label: 'Bairro', value: _dashIfEmpty(district)),
                ] else ...[
                  const Text(
                    'O endereço completo e o pin exato ficam disponíveis após o cliente aceitar.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],

                const SizedBox(height: 10),

                // ✅ texto "oficial" do card (o mesmo que vai para Maps/Rota)
                Text(
                  localAddressDisplay,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                // mapa (se tiver coord). Tap no mapa abre Google Maps com o endereço exibido
                if (lat != null && lng != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: GoogleMap(
                        onMapCreated: (c) async {
                          _mapController = c;

                          // pega minha localização e redesenha markers
                          await _ensureMyLocation();

                          // centraliza:
                          // - após accepted+: centraliza no job
                          // - antes: centraliza em mim (sem pin exato do job)
                          if (canSeeFull) {
                            await c.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: LatLng(lat, lng),
                                  zoom: 15,
                                ),
                              ),
                            );
                          } else {
                            await _centerMapOnMe();
                          }

                          if (mounted) setState(() {});
                        },
                        onTap: (_) => _openPlaceInMapsByQuery(mapsQuery),
                        initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lng),
                          zoom: canSeeFull ? 15 : 12,
                        ),
                        markers: _buildMarkers(
                          showExactJobPin: canSeeFull,
                          jobLat: lat,
                          jobLng: lng,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        liteModeEnabled: false,
                        gestureRecognizers: <Factory<
                            OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 🚗 Distância + ETA (somente após accepted+ para o texto de pin exato)
                  Builder(
                    builder: (_) {
                      if (!canSeeFull) return const SizedBox.shrink();
                      final km = _kmFromMeTo(lat, lng);
                      if (km == null) return const SizedBox.shrink();
                      return Text(
                        'Distância: ${km.toStringAsFixed(1)} km • ETA: ${_etaFromKm(km)} (estimado)',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loadingMyLocation ? null : _centerMapOnMe,
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            _loadingMyLocation
                                ? 'Localizando...'
                                : 'Minha posição',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          // ✅ rota sempre usa o endereço exibido no card
                          // (se não puder ver endereço completo, vai só cidade/uf)
                          onPressed: () =>
                              _openRouteInGoogleMapsByQuery(mapsQuery),
                          icon: const Icon(Icons.directions),
                          label: const Text('Rota'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ✅ botão "Ver distância" só quando status == waiting_providers (como você pediu)
                  if (showDistanceButton)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showDistanceOnly(destLat: lat, destLng: lng),
                        icon: const Icon(Icons.place_outlined),
                        label: const Text('Ver distância'),
                      ),
                    ),

                  if (showDistanceButton) const SizedBox(height: 10),

                  Text(
                    canSeeFull
                        ? 'Toque no mapa para abrir no Google Maps.'
                        : 'Toque no mapa para abrir no Google Maps (cidade/UF).',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ] else ...[
                  // sem lat/lng => ainda assim deixa um "abrir no Maps" pelo endereço exibido
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openPlaceInMapsByQuery(mapsQuery),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Abrir no Maps'),
                    ),
                  ),
                ],
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

  const _FullScreenImagePage({super.key, required this.imageUrl});

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
