import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class ClientPaymentReceiptPage extends ConsumerStatefulWidget {
  const ClientPaymentReceiptPage({
    super.key,
    required this.jobId,
    this.jobTitle,
    this.providerName,
    this.paymentData,
  });

  final String jobId;
  final String? jobTitle;
  final String? providerName;

  /// Dados já carregados — evita query extra quando aberto via job details.
  final Map<String, dynamic>? paymentData;

  @override
  ConsumerState<ClientPaymentReceiptPage> createState() =>
      _ClientPaymentReceiptPageState();
}

class _ClientPaymentReceiptPageState
    extends ConsumerState<ClientPaymentReceiptPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _payment;
  bool _sharing = false;

  final _receiptKey = GlobalKey();
  final _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);
  final _dateFormat = DateFormat("dd/MM/yyyy 'às' HH:mm");

  @override
  void initState() {
    super.initState();
    if (widget.paymentData != null) {
      _payment = widget.paymentData;
      _loading = false;
    } else {
      _load();
    }
  }

  // ── Carregamento ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase
          .from('v_client_job_payments')
          .select('*')
          .eq('job_id', widget.jobId)
          .eq('status', 'paid')
          .order('paid_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) {
        setState(() {
          _loading = false;
          _error = 'Comprovante não disponível ainda.';
        });
        return;
      }
      setState(() {
        _payment = (res as Map).cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar comprovante: $e';
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      return _dateFormat.format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _fmtCpf(String doc) {
    final d = doc.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11) {
      return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
    }
    return doc;
  }

  // ── Exportar como imagem ──────────────────────────────────────────────────

  Future<void> _shareAsImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Garante que o widget está renderizado antes de capturar
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Widget não encontrado.');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Falha ao gerar imagem.');

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/comprovante_renthus_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Comprovante de Pagamento — Renthus',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar imagem: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  left: 8, right: 20, top: 10, bottom: 16),
              color: roxo,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Comprovante',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.black26),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: _load,
                            child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card capturável como imagem
          RepaintBoundary(
            key: _receiptKey,
            child: _buildReceiptCard(),
          ),
          const SizedBox(height: 12),

          // Aviso
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Comprovante gerado pela plataforma Renthus com base nos dados confirmados pelo sistema de pagamentos.',
              style: TextStyle(
                  fontSize: 11, color: Colors.black54, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Botão compartilhar como imagem
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_outlined, size: 18),
              label: Text(
                  _sharing ? 'Gerando imagem...' : 'Compartilhar comprovante'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B246B),
                side: const BorderSide(color: Color(0xFF3B246B)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _sharing ? null : _shareAsImage,
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B246B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Card capturável (imagem compartilhável) ───────────────────────────────

  Widget _buildReceiptCard() {
    final p = _payment!;
    final meta =
        (p['gateway_metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    final pagarme =
        (meta['pagarme'] as Map?)?.cast<String, dynamic>() ?? {};
    final payer =
        (meta['payer'] as Map?)?.cast<String, dynamic>() ?? {};

    final amount = (p['amount_total'] as num?)?.toDouble();
    final amountProvider = (p['amount_provider'] as num?)?.toDouble();
    final paidAt = _fmtDate(p['paid_at']?.toString());
    final orderId = (pagarme['order_id'] as String?) ??
        (p['gateway_transaction_id'] as String?) ??
        '';
    final payerName = (payer['name'] as String?) ?? '';
    final payerDoc = (payer['document'] as String?) ?? '';
    final providerLabel = widget.providerName?.isNotEmpty == true
        ? widget.providerName!
        : null;
    final generatedAt =
        DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho roxo com logo ──────────────────────────────────
          Container(
            color: const Color(0xFF3B246B),
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/renthus_logo_transparent.png',
                  height: 34,
                  color: Colors.white,
                  errorBuilder: (_, __, ___) => const Text(
                    'RENTHUS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'COMPROVANTE DE PAGAMENTO',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // ── Valor e confirmação ──────────────────────────────────────
          Container(
            color: const Color(0xFFF9F9F9),
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34A853),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pagamento confirmado',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF34A853),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (amount != null)
                  Text(
                    _currency.format(amount),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3B246B),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // ── Linha "Pago para" em destaque ────────────────────────────
          if (providerLabel != null)
            Container(
              color: const Color(0xFFF0EBF8),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      color: Color(0xFF3B246B), size: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pago para',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF7B5EA7),
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        providerLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B246B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // ── Detalhes ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _receiptRow('Serviço', widget.jobTitle ?? 'Serviço'),
                _divider(),
                _receiptRow('Data e hora', paidAt),
                _divider(),
                _receiptRow('Forma de pagamento', 'PIX'),
                if (amountProvider != null && amountProvider > 0) ...[
                  _divider(),
                  _receiptRow('Valor ao profissional',
                      _currency.format(amountProvider)),
                ],
                if (payerName.isNotEmpty) ...[
                  _divider(),
                  _receiptRow('Pagador', payerName),
                ],
                if (payerDoc.isNotEmpty) ...[
                  _divider(),
                  _receiptRow('CPF/CNPJ', _fmtCpf(payerDoc)),
                ],
                if (orderId.isNotEmpty) ...[
                  _divider(),
                  _receiptRow('N.° do pedido', orderId),
                ],
              ],
            ),
          ),

          // ── Rodapé ───────────────────────────────────────────────────
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Gerado em $generatedAt',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.black38),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                const Text(
                  'renthus.com.br',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF3B246B),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0));
}
