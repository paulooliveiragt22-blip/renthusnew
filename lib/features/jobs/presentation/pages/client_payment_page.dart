import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/auth/data/repositories/client_repository.dart';
import 'package:renthus/features/jobs/presentation/pages/client_payment_receipt_page.dart';
import 'package:renthus/utils/brazilian_validators.dart';
import 'package:renthus/utils/payment_calculator.dart';

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

  // Seleção de método de pagamento
  // null = nenhum selecionado; true = PIX; false = crédito
  bool? _selectedPix;
  bool _creditInstallment = false;      // toggle "Parcelar"
  InstallmentOption? _selectedInstallment;

  // Dados do PIX — preenchidos após create-payment
  String? _paymentId;
  String? _pixCode;       // código copia-e-cola

  // Crédito — aguardando confirmação (sem QR Code)
  bool _creditPending = false;

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

  // ─── Garantir CPF antes de pagar ───────────────────────────────────────────

  /// Retorna true se o cliente já tem CPF ou se conseguiu coletar um agora.
  Future<bool> _ensureCpf() async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await supabase
        .from('clients')
        .select('cpf')
        .eq('id', userId)
        .maybeSingle();

    final cpf = (row as Map?)?['cpf']?.toString() ?? '';
    if (cpf.isNotEmpty) return true; // CPF já cadastrado

    // CPF ausente → coleta via bottom sheet
    if (!mounted) return false;
    final collected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CpfCollectionSheet(
        onSave: (cpfDigits) async {
          final repo = ClientRepository(client: supabase);
          await repo.setCpf(cpfDigits);
        },
      ),
    );
    return collected == true;
  }

  // ─── Gerar cobrança PIX ────────────────────────────────────────────────────

  Future<void> _generatePix() async {
    if (_paying) return;

    final supabase = ref.read(supabaseProvider);
    if (supabase.auth.currentUser == null) {
      _snack('Faça login novamente para continuar.');
      return;
    }

    // Garantir CPF antes de criar a cobrança
    final hasCpf = await _ensureCpf();
    if (!hasCpf) {
      if (mounted) _snack('O CPF é obrigatório para pagamentos via PIX.');
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
          'method': 'pix',
          'installments': 1,
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

      // Se o servidor já aprovou automaticamente (sandbox), mostra comprovante
      if (data['auto_approved'] == true) {
        Future.delayed(const Duration(milliseconds: 1200), () async {
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientPaymentReceiptPage(
                jobId: widget.jobId,
                jobTitle: widget.jobTitle,
                providerName: widget.providerName,
              ),
            ),
          );
          if (mounted) Navigator.pop(context, true);
        });
        return;
      }

      _startPolling();
      _startCountdown();
    } catch (e) {
      setState(() { _paying = false; _error = 'Erro: $e'; });
      _snack(_error!);
    }
  }

  // ─── Polling: verifica se o pagamento foi confirmado ──────────────────────

  int _pollCount = 0;

  void _startPolling() {
    _pollCount = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPaymentStatus());
  }

  Future<void> _checkPaymentStatus() async {
    if (!mounted) return;
    _pollCount++;

    try {
      final supabase = ref.read(supabaseProvider);

      // A cada 3 ciclos (15s), também consulta o Pagar.me diretamente como fallback
      // caso o webhook não tenha chegado.
      if (_pollCount % 3 == 0 && _paymentId != null) {
        await _checkPaymentViaApi(supabase);
      }

      // Consulta jobs (cliente tem acesso via RLS)
      final row = await supabase
          .from('jobs')
          .select('payment_status')
          .eq('id', widget.jobId)
          .maybeSingle();

      if (row == null) return;

      if (row['payment_status'] == 'paid') {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientPaymentReceiptPage(
              jobId: widget.jobId,
              jobTitle: widget.jobTitle,
              providerName: widget.providerName,
            ),
          ),
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }

      if (row['payment_status'] == 'failed') {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _pixCode            = null;
          _paymentId          = null;
          _creditPending      = false;
          _selectedPix        = null;
          _selectedInstallment = null;
          _creditInstallment  = false;
          _paying             = false;
          _remainingSeconds   = 3600;
          _error              = null;
        });
        _snack('Pagamento não aprovado. Escolha outra forma de pagamento e tente novamente.');
      }
    } catch (_) {}
  }

  /// Fallback: chama edge function que consulta Pagar.me e atualiza o banco se pago.
  Future<void> _checkPaymentViaApi(dynamic supabase) async {
    try {
      await supabase.functions.invoke(
        'check-payment',
        body: {
          'payment_id': _paymentId,
          'sandbox': _isSandbox,
        },
      );
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

  // ─── Renovar PIX expirado ──────────────────────────────────────────────────

  Future<void> _renewPix() async {
    setState(() {
      _pixCode = null;
      _paymentId = null;
      _remainingSeconds = 3600;
      _error = null;
    });
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    await _generatePix();
  }

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
            else if (_error != null && _pixCode == null && !_creditPending)
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
            else if (_creditPending)
              Expanded(child: _buildCreditPendingScreen(roxo))
            else
              Expanded(child: _buildConfirmScreen(roxo)),
          ],
        ),
      ),
    );
  }

  // ─── Selecionar método e confirmar pagamento ──────────────────────────────

  Future<void> _confirm() async {
    if (_paying) return;
    if (_selectedPix == true) {
      await _generatePix();
    } else if (_selectedPix == false) {
      final amountNum = _quote?['approximate_price'];
      if (amountNum == null) return;
      final providerAmount = (amountNum as num).toDouble();
      final summary = PaymentCalculator.getSummary(providerAmount);

      if (!_creditInstallment) {
        // Crédito à vista: 1x com taxa menor
        await _submitCreditCard(InstallmentOption(
          number: 1,
          installmentValue: summary.creditCashTotal,
          total: summary.creditCashTotal,
          available: true,
        ));
      } else if (_selectedInstallment != null) {
        await _submitCreditCard(_selectedInstallment!);
      }
    }
  }

  Future<void> _submitCreditCard(InstallmentOption option) async {
    final supabase = ref.read(supabaseProvider);
    if (supabase.auth.currentUser == null) {
      _snack('Faça login novamente para continuar.');
      return;
    }

    final hasCpf = await _ensureCpf();
    if (!hasCpf) {
      if (mounted) _snack('O CPF é obrigatório para pagamentos.');
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
          'method': 'credit_card',
          'installments': option.number,
          'amount': option.total,
        },
      );

      final data = res.data as Map?;
      if (res.status != 200 || data == null || data['ok'] != true) {
        throw Exception(data?['error'] ?? 'Falha ao processar pagamento');
      }

      final paymentMap = data['payment'] as Map?;
      setState(() {
        _paymentId = paymentMap?['id']?.toString();
        _paying = false;
        _creditPending = true;
      });

      // Polling idêntico ao PIX
      _startPolling();
    } catch (e) {
      setState(() { _paying = false; _error = 'Erro: $e'; });
      _snack(_error!);
    }
  }

  // ─── Tela de seleção de método ────────────────────────────────────────────

  Widget _buildConfirmScreen(Color roxo) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);
    final q = _quote;
    final j = _job;

    final title     = (j?['title'] as String?) ?? widget.jobTitle ?? 'Serviço';
    final provLabel = widget.providerName ?? 'Profissional escolhido';
    final amountNum = q?['approximate_price'];
    final double? providerAmount = amountNum is num ? amountNum.toDouble() : null;
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

    if (providerAmount == null) {
      return const Center(child: Text('Valor não disponível.'));
    }

    final summary = PaymentCalculator.getSummary(providerAmount);

    // Valor do botão de confirmação
    String confirmLabel = 'Confirmar e pagar';
    bool confirmEnabled = false;
    if (_selectedPix == true) {
      confirmLabel = 'Confirmar e pagar ${currency.format(summary.pixTotal)}';
      confirmEnabled = true;
    } else if (_selectedPix == false) {
      if (!_creditInstallment) {
        confirmLabel = 'Confirmar e pagar ${currency.format(summary.creditCashTotal)}';
        confirmEnabled = true;
      } else if (_selectedInstallment != null) {
        confirmLabel = 'Confirmar e pagar ${currency.format(_selectedInstallment!.total)}';
        confirmEnabled = true;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do serviço
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3B246B))),
                const SizedBox(height: 4),
                Text('Prestador: $provLabel',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Escolha a forma de pagamento',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3B246B))),
          const SizedBox(height: 10),

          // ── Card PIX ────────────────────────────────────────────────────
          _MethodCard(
            selected: _selectedPix == true,
            onTap: () => setState(() {
              _selectedPix = true;
              _selectedInstallment = null;
            }),
            child: Row(
              children: [
                const Icon(Icons.pix, color: Color(0xFF32C768), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PIX',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Aprovado na hora • taxa 1,09%',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text(
                  currency.format(summary.pixTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF3B246B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Card crédito ─────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() { _selectedPix = false; }),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedPix == false
                      ? const Color(0xFF3B246B)
                      : Colors.grey.shade200,
                  width: _selectedPix == false ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        Icon(Icons.credit_card_outlined,
                            color: Color(0xFF3B246B), size: 22),
                        SizedBox(width: 10),
                        Text('Cartão de crédito',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF3B246B))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),

                  // À vista + toggle Parcelar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('À vista',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                currency.format(summary.creditCashTotal),
                                style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF3B246B),
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        Text('Parcelar',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700)),
                        const SizedBox(width: 2),
                        Switch(
                          value: _creditInstallment,
                          onChanged: (v) => setState(() {
                            _selectedPix = false;
                            _creditInstallment = v;
                            _selectedInstallment = null;
                          }),
                          activeThumbColor: const Color(0xFF3B246B),
                          activeTrackColor: const Color(0xFF7B5CB8),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),

                  // Parcelas (toggle ON — somente available)
                  if (_creditInstallment) ...[
                    const Divider(height: 1, thickness: 1),
                    ...summary.installments
                        .where((opt) => opt.number > 1 && opt.available)
                        .map((opt) {
                      final isSelected =
                          _selectedInstallment?.number == opt.number;
                      return _InstallmentRow(
                        option: opt,
                        selected: isSelected,
                        disabled: false,
                        currency: currency,
                        onTap: () => setState(() {
                          _selectedPix = false;
                          _selectedInstallment = opt;
                        }),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // Aviso de parcelamento
          if (_selectedPix == false &&
              _creditInstallment &&
              _selectedInstallment != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('Valor inclui taxa de parcelamento.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Botão confirmar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B246B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_paying || !confirmEnabled) ? null : _confirm,
              child: _paying
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(confirmLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Tela de crédito aguardando confirmação ────────────────────────────────

  Widget _buildCreditPendingScreen(Color roxo) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56, height: 56,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF3B246B)),
            ),
            SizedBox(height: 24),
            Text(
              'Aguardando confirmação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3B246B)),
            ),
            SizedBox(height: 10),
            Text(
              'O pagamento está sendo processado.\nVocê será notificado quando confirmado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
          ],
        ),
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
                onPressed: _paying ? null : _renewPix,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B246B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _paying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Gerar novo QR Code',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Card genérico de método de pagamento ────────────────────────────────────

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF3B246B) : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─── Linha de parcela dentro do card de crédito ───────────────────────────────

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.currency,
    required this.onTap,
  });

  final InstallmentOption option;
  final bool selected;
  final bool disabled;
  final NumberFormat currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = disabled ? Colors.grey.shade400 : Colors.black87;
    final bg = selected ? const Color(0xFFEDE8F7) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // Rádio visual
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: disabled
                      ? Colors.grey.shade300
                      : selected
                          ? const Color(0xFF3B246B)
                          : Colors.grey.shade500,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF3B246B),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.number == 1
                    ? '1× (à vista)'
                    : '${option.number}× de ${currency.format(option.installmentValue)}',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              'Total ${currency.format(option.total)}',
              style: TextStyle(fontSize: 12, color: disabled ? Colors.grey.shade400 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet para coletar CPF de clientes existentes ───────────────────

class _CpfCollectionSheet extends StatefulWidget {
  const _CpfCollectionSheet({required this.onSave});
  final Future<void> Function(String cpfDigits) onSave;

  @override
  State<_CpfCollectionSheet> createState() => _CpfCollectionSheetState();
}

class _CpfCollectionSheetState extends State<_CpfCollectionSheet> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final digits = _ctrl.text.replaceAll(RegExp(r'\D'), '');
      await widget.onSave(digits);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar CPF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe seu CPF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O CPF é exigido pelo sistema de pagamentos PIX para confirmar sua identidade. Será salvo no seu cadastro.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CpfFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'CPF',
                hintText: '000.000.000-00',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                if (d.isEmpty) return 'Informe o CPF.';
                if (!BrazilianValidators.isValidCPF(d)) return 'CPF inválido.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B246B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salvar e continuar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
