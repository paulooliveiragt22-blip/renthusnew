import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class ClientPaymentPage extends ConsumerStatefulWidget {
  const ClientPaymentPage({
    super.key,
    required this.jobId,
    required this.quoteId,
    this.jobTitle,
    this.providerName,
  });

  final String jobId;
  final String quoteId;
  final String? jobTitle;
  final String? providerName;

  @override
  ConsumerState<ClientPaymentPage> createState() => _ClientPaymentPageState();
}

class _ClientPaymentPageState extends ConsumerState<ClientPaymentPage> {
  // Estados da tela
  bool _loading = true;
  bool _paying = false;
  String? _error;

  // Dados do job/quote
  Map<String, dynamic>? _job;
  Map<String, dynamic>? _quote;

  // Dados do PIX — preenchidos após create-payment
  String? _paymentId;
  String? _pixCode;       // código copia-e-cola

  // Polling & countdown
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 3600;

  bool get _isSandbox => dotenv.env['PAGARME_SANDBOX'] == 'true';

  @override
  void initState() {
    super.initState();
    _loadJobAndQuote();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ─── Carregamento inicial ──────────────────────────────────────────────────

  Future<void> _loadJobAndQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final supabase = ref.read(supabaseProvider);

    try {
      final j = await supabase
          .from('jobs')
          .select('id, title, status, provider_id, payment_status, price')
          .eq('id', widget.jobId)
          .maybeSingle();

      if (j == null) {
        setState(() { _loading = false; _error = 'Pedido não encontrado.'; });
        return;
      }

      final q = await supabase
          .from('job_quotes')
          .select('id, job_id, provider_id, approximate_price, is_accepted')
          .eq('id', widget.quoteId)
          .maybeSingle();

      if (q == null || q['job_id'] != widget.jobId) {
        setState(() { _loading = false; _error = 'Orçamento não encontrado.'; });
        return;
      }

      setState(() {
        _job = (j as Map).cast<String, dynamic>();
        _quote = (q as Map).cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Erro ao carregar: $e'; });
    }
  }

  // ─── Gerar cobrança PIX ────────────────────────────────────────────────────

  Future<void> _generatePix() async {
    if (_paying) return;

    final supabase = ref.read(supabaseProvider);
    if (supabase.auth.currentUser == null) {
      _snack('Faça login novamente para continuar.');
      return;
    }

    setState(() { _paying = true; _error = null; });

    try {
      final res = await supabase.functions.invoke(
        'create-payment',
        body: {
          'job_id': widget.jobId,
          'quote_id': widget.quoteId,
          'sandbox': _isSandbox,
        },
      );

      final data = res.data as Map?;

      if (res.status != 200 || data == null || data['ok'] != true) {
        throw Exception(data?['error'] ?? 'Falha ao gerar cobrança PIX');
      }

      final pix = data['pix'] as Map?;
      final paymentMap = data['payment'] as Map?;

      if (pix == null || (pix['qr_code'] as String? ?? '').isEmpty) {
        throw Exception('QR Code não retornado pelo servidor. Tente novamente.');
      }

      final expiresAtStr = pix['expires_at'] as String? ?? '';
      final expiry = expiresAtStr.isNotEmpty
          ? DateTime.tryParse(expiresAtStr)?.toLocal()
          : null;

      setState(() {
        _paymentId = paymentMap?['id']?.toString();
        _pixCode = pix['copy_paste'] as String? ?? pix['qr_code'] as String;
        _remainingSeconds = expiry != null
            ? expiry.difference(DateTime.now()).inSeconds.clamp(0, 7200)
            : 3600;
        _paying = false;
      });

      _startPolling();
      _startCountdown();
    } catch (e) {
      setState(() { _paying = false; _error = 'Erro: $e'; });
      _snack(_error!);
    }
  }

  // ─── Polling: verifica se o pagamento foi confirmado ──────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPaymentStatus());
  }

  Future<void> _checkPaymentStatus() async {
    if (_paymentId == null || !mounted) return;

    try {
      final supabase = ref.read(supabaseProvider);
      final row = await supabase
          .from('payments')
          .select('status')
          .eq('id', _paymentId!)
          .maybeSingle();

      if (row == null) return;

      if (row['status'] == 'paid') {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) Navigator.pop(context, true);
      }
    } catch (_) {}
  }

  // ─── Countdown regressivo do PIX ──────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds = (_remainingSeconds - 1).clamp(0, 7200);
      });
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
      }
    });
  }

  String get _countdownLabel {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _pixExpired => _remainingSeconds <= 0;

  // ─── Copiar código PIX ────────────────────────────────────────────────────

  Future<void> _copyPixCode() async {
    if (_pixCode == null) return;
    await Clipboard.setData(ClipboardData(text: _pixCode!));
    if (mounted) _snack('Código PIX copiado!');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            // Banner sandbox
            if (_isSandbox)
              Container(
                width: double.infinity,
                color: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Text(
                  'AMBIENTE DE TESTE — pagamentos não são reais',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),

            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 8, right: 20, top: 10, bottom: 16),
              color: roxo,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pagamento via PIX',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Corpo
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _pixCode == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadJobAndQuote, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                ),
              )
            else if (_pixCode != null)
              Expanded(child: _buildPixScreen(roxo))
            else
              Expanded(child: _buildConfirmScreen(roxo)),
          ],
        ),
      ),
    );
  }

  // ─── Tela de confirmação (antes de gerar o PIX) ───────────────────────────

  Widget _buildConfirmScreen(Color roxo) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);
    final q = _quote;
    final j = _job;

    final title = (j?['title'] as String?) ?? widget.jobTitle ?? 'Serviço';
    final providerLabel = widget.providerName ?? 'Profissional escolhido';
    final amountNum = q?['approximate_price'];
    final double? amount = amountNum is num ? amountNum.toDouble() : null;
    final alreadyPaid = (j?['payment_status'] as String?) == 'paid';

    if (alreadyPaid) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF34A853), size: 64),
              const SizedBox(height: 16),
              const Text('Pagamento já confirmado!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('O prestador já foi notificado e pode iniciar o serviço.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Voltar ao pedido'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo do pagamento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF3B246B))),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3B246B))),
                const SizedBox(height: 6),
                Text('Prestador: $providerLabel', style: const TextStyle(fontSize: 13)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Valor total', style: TextStyle(fontSize: 14)),
                    Text(
                      amount != null ? currency.format(amount) : '—',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF3B246B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.pix, color: Color(0xFF32C768), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagar com PIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 2),
                      Text('QR Code gerado na hora. Pague em qualquer banco.',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32C768),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_paying || amount == null) ? null : _generatePix,
              child: _paying
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Gerar QR Code PIX', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tela do QR Code PIX ──────────────────────────────────────────────────

  Widget _buildPixScreen(Color roxo) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);
    final amountNum = _quote?['approximate_price'];
    final double? amount = amountNum is num ? amountNum.toDouble() : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Status e countdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _pixExpired ? Colors.red.shade50 : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _pixExpired ? Icons.timer_off : Icons.timer,
                  color: _pixExpired ? Colors.red : const Color(0xFF34A853),
                ),
                const SizedBox(width: 8),
                if (_pixExpired)
                  const Text('PIX expirado. Volte e tente novamente.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))
                else ...[
                  const Text('Expira em ', style: TextStyle(fontSize: 13)),
                  Text(_countdownLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF34A853))),
                  const Spacer(),
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34A853)),
                  ),
                  const SizedBox(width: 6),
                  const Text('Verificando...', style: TextStyle(fontSize: 11, color: Colors.black45)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Valor
          if (amount != null)
            Text(
              currency.format(amount),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3B246B)),
            ),
          const SizedBox(height: 4),
          Text(
            (widget.jobTitle ?? _job?['title'] as String? ?? 'Serviço'),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // QR Code
          if (!_pixExpired) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
              ),
              child: QrImageView(
                data: _pixCode!,
                version: QrVersions.auto,
                size: 220,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF3B246B)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF3B246B)),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Copia-e-cola
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PIX Copia e Cola',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF3B246B))),
                const SizedBox(height: 8),
                Text(
                  _pixCode!,
                  style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar código'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3B246B)),
                      foregroundColor: const Color(0xFF3B246B),
                    ),
                    onPressed: _copyPixCode,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Instruções
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Como pagar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 6),
                Text('1. Abra o app do seu banco', style: TextStyle(fontSize: 12)),
                Text('2. Escolha pagar via PIX', style: TextStyle(fontSize: 12)),
                Text('3. Escaneie o QR Code ou cole o código', style: TextStyle(fontSize: 12)),
                Text('4. Confirme o pagamento', style: TextStyle(fontSize: 12)),
                SizedBox(height: 6),
                Text('O pedido é confirmado automaticamente após o pagamento.',
                    style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),

          if (_pixExpired) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Voltar e tentar novamente'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
