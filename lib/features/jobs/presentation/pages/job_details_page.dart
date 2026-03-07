import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/screens/provider_job_details/job_bottom_bar.dart';
import 'package:renthus/screens/provider_verification_page.dart';
import 'package:renthus/screens/provider_job_details/job_helpers.dart';
import 'package:renthus/screens/provider_job_details/job_values_section.dart';
import 'package:renthus/screens/provider_job_details/provider_quote_schedule_section.dart';
import 'package:renthus/core/utils/error_handler.dart';
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
  bool _isChangingStatus = false;
  bool _isAcceptingQuoteSlot = false;

  // Agendamento da proposta (data+hora início e fim; duração calculada)
  DateTime? _proposedStartAt;
  DateTime? _proposedEndAt;
  bool _scheduleInitialized = false;

  @override
  void dispose() {
    _counterPriceController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    RenthusCenterMessage.show(context, text);
  }

  void _showVerificationRequired() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Verificação necessária',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para enviar propostas, você precisa completar a verificação da sua conta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ProviderVerificationPage(),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B246B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Completar verificação'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _showDistanceOnly(
      {required double destLat, required double destLng}) async {
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
        _showMessage('Permissão de localização negada. Ative nas configurações do app.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('timeout'),
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
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('timeout')
          ? 'GPS demorou demais. Tente em local aberto.'
          : 'Não foi possível calcular a distância.';
      _showMessage(msg);
    }
  }

  Future<void> _openOnMap(double lat, double lng, {String? addressQuery}) async {
    final query = (addressQuery != null && addressQuery.isNotEmpty)
        ? Uri.encodeComponent(addressQuery)
        : '$lat,$lng';
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
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
      case 'open':
        return 'Disponível';
      case 'accepted':
        return 'Aceito';
      case 'on_the_way':
        return 'A caminho';
      case 'in_progress':
        return 'Em execução';
      case 'execution_overdue':
        return 'Fora do prazo';
      case 'completed':
        return 'Finalizado';
      case 'dispute':
      case 'dispute_open':
        return 'Em disputa';
      case 'refunded':
        return 'Estornado';
      case 'cancelled':
        return 'Cancelado';
      case 'cancelled_by_client':
        return 'Cancelado pelo cliente';
      case 'cancelled_by_provider':
        return 'Cancelado por você';
      default:
        return s.isEmpty ? 'Indefinido' : s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'waiting_providers':
      case 'open':
        return Colors.blueGrey;
      case 'accepted':
      case 'on_the_way':
      case 'in_progress':
        return const Color(0xFF34A853);
      case 'execution_overdue':
        return Colors.red;
      case 'completed':
        return const Color(0xFF3B246B);
      case 'dispute':
      case 'dispute_open':
        return const Color(0xFFFF3B30);
      case 'refunded':
        return const Color(0xFF0DAA00);
      case 'cancelled':
      case 'cancelled_by_client':
      case 'cancelled_by_provider':
        return Colors.red.shade600;
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

    final deadlineRaw = j['my_quote_deadline_at'];
    DateTime? deadline;
    if (deadlineRaw != null) {
      deadline = DateTime.tryParse(deadlineRaw.toString())?.toLocal();
    }
    if (deadline == null || !deadline.isAfter(DateTime.now())) {
      _showMessage(
        'Aceite o pedido e envie seu orçamento em até 2 horas.',
      );
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

    if (_proposedStartAt == null) {
      _showMessage('Selecione a data e hora de início.');
      return;
    }
    if (_proposedEndAt == null) {
      _showMessage('Selecione a data e hora de fim.');
      return;
    }
    if (_proposedEndAt!.isBefore(_proposedStartAt!) ||
        _proposedEndAt!.isAtSameMomentAs(_proposedStartAt!)) {
      _showMessage('A data/hora de fim deve ser após o início.');
      return;
    }

    setState(() => _isSendingQuote = true);

    try {
      final repo = ref.read(appJobRepositoryProvider);
      final durationMinutes =
          _proposedEndAt!.difference(_proposedStartAt!).inMinutes;
      await repo.submitJobQuote(
        jobId: widget.jobId,
        approximatePrice: chosenPrice,
        message: null,
        proposedStartAt: _proposedStartAt,
        proposedEndAt: _proposedEndAt,
        estimatedDurationMinutes: durationMinutes,
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

  Future<void> _acceptQuoteSlot() async {
    if (_isAcceptingQuoteSlot) return;
    setState(() => _isAcceptingQuoteSlot = true);
    try {
      final repo = ref.read(appJobRepositoryProvider);
      final res = await repo.providerAcceptJobForQuote(jobId: widget.jobId);
      if (!mounted) return;

      final deadline = res['quote_deadline_at']?.toString();
      if (deadline != null && deadline.isNotEmpty) {
        final parsed = DateTime.tryParse(deadline)?.toLocal();
        if (parsed != null) {
          _showMessage(
            'Pedido aceito. Envie o orçamento até ${DateFormat('dd/MM HH:mm').format(parsed)}.',
          );
        } else {
          _showMessage(
              'Pedido aceito. Você tem 2 horas para enviar o orçamento.');
        }
      } else {
        _showMessage(
            'Pedido aceito. Você tem 2 horas para enviar o orçamento.');
      }
      ref.invalidate(providerJobByIdProvider(widget.jobId));
    } catch (e) {
      if (!mounted) return;
      _showMessage(ErrorHandler.friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isAcceptingQuoteSlot = false);
    }
  }

  Future<void> _setOnTheWayWithEta({
    required double? jobLat,
    required double? jobLng,
  }) async {
    int? etaMinutes;
    if (jobLat != null && jobLng != null) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm != LocationPermission.denied &&
              perm != LocationPermission.deniedForever) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('timeout'),
            );
            final km =
                _distanceKm(pos.latitude, pos.longitude, jobLat, jobLng);
            etaMinutes = ((km / 30.0) * 60).ceil().clamp(1, 999);
          }
        }
      } catch (_) {
        // ETA é opcional — prossegue sem ele se GPS falhar
      }
    }
    await _updateAssignedJobStatus('on_the_way', etaMinutes: etaMinutes);
  }

  Future<void> _updateAssignedJobStatus(String newStatus,
      {int? etaMinutes}) async {
    if (_isChangingStatus) return;
    setState(() => _isChangingStatus = true);
    try {
      final repo = ref.read(appJobRepositoryProvider);
      await repo.providerSetJobStatus(
        jobId: widget.jobId,
        newStatus: newStatus,
        etaMinutes: etaMinutes,
      );
      if (!mounted) return;
      String msg = JobHelpers.friendlyStatusUpdatedMessage(newStatus);
      if (newStatus == 'on_the_way' && etaMinutes != null) {
        msg = 'Você está a caminho! Tempo estimado de chegada: ~$etaMinutes min.';
      }
      _showMessage(msg);
      ref.invalidate(providerJobByIdProvider(widget.jobId));
    } catch (e) {
      if (!mounted) return;
      _showMessage(ErrorHandler.friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isChangingStatus = false);
    }
  }

  Future<void> _openAssignedChat(Map<String, dynamic> job) async {
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) {
      _showMessage('Faça login novamente para acessar o chat.');
      return;
    }

    final jobId = (job['id'] ?? '').toString();
    final clientId = (job['client_id'] ?? '').toString();
    if (jobId.isEmpty || clientId.isEmpty) {
      _showMessage('Não foi possível abrir a conversa deste serviço.');
      return;
    }

    try {
      final chatRepo = ref.read(legacyChatRepositoryProvider);
      final conv = await chatRepo.upsertConversationForJob(
        jobId: jobId,
        clientId: clientId,
        providerId: user.id,
        title: (job['title'] ?? job['description'] ?? 'Chat do serviço')
            .toString(),
      );

      if (conv == null || conv['id'] == null) {
        _showMessage('Não foi possível abrir o chat agora.');
        return;
      }

      final conversationId = conv['id'].toString();
      final otherUserName = (job['client_name'] ?? 'Cliente').toString();
      final status = (job['status'] as String?) ?? '';
      final chatLocked = (status == 'completed' ||
              status == 'refunded' ||
              status == 'cancelled' ||
              status.startsWith('cancelled_')) &&
          (job['dispute_open'] != true);

      if (!mounted) return;
      await context.pushChat({
        'conversationId': conversationId,
        'jobTitle': (job['title'] ?? 'Chat do serviço').toString(),
        'otherUserName': otherUserName,
        'currentUserId': user.id,
        'currentUserRole': 'provider',
        'isChatLocked': chatLocked,
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(ErrorHandler.friendlyErrorMessage(e));
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

  TimeOfDay _parseTime(dynamic v) {
    if (v == null) return const TimeOfDay(hour: 8, minute: 0);
    final s = v.toString().trim();
    if (s.isEmpty) return const TimeOfDay(hour: 8, minute: 0);
    final parts = s.split(RegExp(r'[:\s]'));
    if (parts.isEmpty) return const TimeOfDay(hour: 8, minute: 0);
    final h = int.tryParse(parts[0]) ?? 8;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  void _initScheduleFromJob(Map<String, dynamic> j) {
    if (_scheduleInitialized) return;
    _scheduleInitialized = true;
    final hasFlexible = j['has_flexible_schedule'] != false;
    if (hasFlexible) return;

    DateTime? d;
    try {
      final sd = j['scheduled_date'];
      if (sd != null) d = DateTime.parse(sd.toString());
    } catch (_) {}

    final ss = j['scheduled_start_time']?.toString();
    final se = j['scheduled_end_time']?.toString();

    // Só pré-preenche início quando cliente definiu data + hora de início
    // (esses campos ficam bloqueados para edição pelo prestador)
    if (d != null && ss != null) {
      final startParts = ss.split(RegExp(r'[:\s]'));
      if (startParts.isNotEmpty) {
        final sh = int.tryParse(startParts[0]) ?? 8;
        final sm = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
        DateTime start = DateTime(d.year, d.month, d.day, sh, sm);

        DateTime? end;
        if (se != null) {
          final endParts = se.split(RegExp(r'[:\s]'));
          if (endParts.isNotEmpty) {
            final eh = int.tryParse(endParts[0]) ?? 17;
            final em = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;
            end = DateTime(d.year, d.month, d.day, eh, em);
            if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
              end = start.add(const Duration(hours: 9));
            }
          }
        }

        setState(() {
          _proposedStartAt = start;
          _proposedEndAt = end;
        });
      }
    }
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
        final selectedNetPrice = (_priceChoice == 'accept' &&
                offeredPrice != null &&
                offeredPrice > 0)
            ? _netFromPrice(offeredPrice)
            : null;

        final status = (job['status'] as String?) ?? '';

        final vStatus = ref.watch(providerMeProvider).valueOrNull
            ?['verification_status'] as String? ?? 'pending';

        DateTime? quoteDeadline;
        final deadlineRaw = job['my_quote_deadline_at'];
        if (deadlineRaw != null) {
          quoteDeadline =
              DateTime.tryParse(deadlineRaw.toString())?.toLocal();
        }
        final hasActiveQuoteWindow =
            quoteDeadline != null && quoteDeadline.isAfter(DateTime.now());

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
          bottomNavigationBar: isAssigned
              ? JobBottomBar(
                  job: job,
                  isAssigned: true,
                  isCandidate: false,
                  isChangingStatus: _isChangingStatus,
                  hasOpenDispute: false,
                  canAcceptBeforeMatch: false,
                  verificationStatus: vStatus,
                  onRejectJob: () => _showMessage('Ação não usada aqui.'),
                  onAcceptBeforeMatch: () =>
                      _showMessage('Ação não usada aqui.'),
                  onSetOnTheWay: () => _setOnTheWayWithEta(
                    jobLat: (job['lat'] as num?)?.toDouble(),
                    jobLng: (job['lng'] as num?)?.toDouble(),
                  ),
                  onSetInProgress: () =>
                      _updateAssignedJobStatus('in_progress'),
                  onSetCompleted: () => _updateAssignedJobStatus('completed'),
                  onOpenChat: () => _openAssignedChat(job),
                  onOpenDispute: null,
                  onCancelAfterMatch: null,
                )
              : (status == 'waiting_providers' && !hasActiveQuoteWindow)
                  ? SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isAcceptingQuoteSlot
                                ? null
                                : () {
                                    if (vStatus != 'active') {
                                      _showVerificationRequired();
                                      return;
                                    }
                                    _acceptQuoteSlot();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34A853),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isAcceptingQuoteSlot
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.schedule_send_outlined),
                            label: const Text(
                              'Aceitar pedido (2h para orçamento)',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
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

  String? _fmtTimeForDisplay(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.isEmpty) return null;
    final h = parts[0].padLeft(2, '0');
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    return '$h:$m';
  }

  List<Map<String, dynamic>> _parseDocuments(dynamic docsJson) {
    final docs = <Map<String, dynamic>>[];
    if (docsJson is List) {
      for (final item in docsJson) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final url = (m['url'] ?? '').toString().trim();
          if (url.isEmpty) continue;
          docs.add({
            'url': url,
            'filename': (m['filename'] ?? 'Documento.pdf').toString(),
            'mime_type': (m['mime_type'] ?? 'application/pdf').toString(),
          });
        }
      }
    }
    return docs;
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
    final addressStreet = (j['address_street'] as String?)?.trim() ?? '';
    final addressNumber = (j['address_number'] as String?)?.trim() ?? '';
    final addressDistrict = (j['address_district'] as String?)?.trim() ?? '';
    final createdAt = _fmtDate(j['created_at']);
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final statusColor = _statusColor(status);
    final docs = _parseDocuments(j['documents']);
    DateTime? quoteDeadline;
    final deadlineRaw = j['my_quote_deadline_at'];
    if (deadlineRaw != null) {
      quoteDeadline = DateTime.tryParse(deadlineRaw.toString())?.toLocal();
    }
    final hasActiveQuoteWindow =
        quoteDeadline != null && quoteDeadline.isAfter(DateTime.now());

    if (!_scheduleInitialized && j.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initScheduleFromJob(j);
      });
    }

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
          _buildDocumentsSection(docs),
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
                if (['accepted', 'on_the_way', 'in_progress', 'dispute']
                        .contains(status) &&
                    (addressStreet.isNotEmpty ||
                        addressDistrict.isNotEmpty)) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF3B246B),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            [addressStreet, addressNumber]
                                .where((s) => s.isNotEmpty)
                                .join(', '),
                            addressDistrict,
                          ].where((s) => s.isNotEmpty).join('\n'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                    if (['accepted', 'on_the_way', 'in_progress', 'dispute']
                        .contains(status)) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (lat == null || lng == null)
                              ? null
                              : () {
                                  // Só usa texto quando a rua está preenchida;
                                  // caso contrário usa lat/lng (mais preciso que só "Cidade, UF")
                                  String? addrQuery;
                                  if (addressStreet.isNotEmpty) {
                                    final parts = [
                                      [addressStreet, addressNumber]
                                          .where((s) => s.isNotEmpty)
                                          .join(', '),
                                      addressDistrict,
                                      city,
                                      uf,
                                    ].where((s) => s.isNotEmpty).toList();
                                    addrQuery = parts.isNotEmpty
                                        ? parts.join(', ')
                                        : null;
                                  }
                                  _openOnMap(lat, lng, addressQuery: addrQuery);
                                },
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Abrir no mapa'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  (lat == null || lng == null)
                      ? 'Localização indisponível para este pedido.'
                      : ['accepted', 'on_the_way', 'in_progress', 'dispute']
                              .contains(status)
                          ? 'Endereço e localização exata do serviço.'
                          : 'Localização aproximada (±1 km).',
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
            if (status == 'waiting_providers') ...[
              const SizedBox(height: 14),
              if (hasActiveQuoteWindow)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Prazo para orçamento: ${DateFormat('dd/MM/yyyy HH:mm').format(quoteDeadline)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ProviderQuoteScheduleSection(
                hasFlexibleSchedule: j['has_flexible_schedule'] != false,
                clientScheduledDate: j['scheduled_date'] != null
                    ? DateTime.tryParse(j['scheduled_date'].toString())
                    : null,
                clientStartTime: _fmtTimeForDisplay(j['scheduled_start_time']),
                clientEndTime: _fmtTimeForDisplay(j['scheduled_end_time']),
                proposedStartAt: _proposedStartAt,
                proposedEndAt: _proposedEndAt,
                onStartAtChanged: (dt) => setState(() => _proposedStartAt = dt),
                onEndAtChanged: (dt) => setState(() => _proposedEndAt = dt),
              ),
            ],
          ],
          const SizedBox(height: 18),
          if (!isAssigned && status == 'waiting_providers') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSendingQuote || !hasActiveQuoteWindow)
                    ? null
                    : _sendQuote,
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

  Widget _buildDocumentsSection(List<Map<String, dynamic>> docs) {
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
            'Documentos PDF (${docs.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (docs.isEmpty)
            const Text(
              'Nenhum documento anexado.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            ...docs.map(
              (d) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(
                  (d['filename'] ?? 'Documento.pdf').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle:
                    Text((d['mime_type'] ?? 'application/pdf').toString()),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final url = (d['url'] ?? '').toString();
                  if (url.isEmpty) return;
                  await launchUrlString(url);
                },
              ),
            ),
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
    await context.pushFullImage(url);
  }
}

class _ParsedPhotos {
  _ParsedPhotos({required this.urls, required this.thumbs});
  final List<String> urls;
  final List<String> thumbs;
}
