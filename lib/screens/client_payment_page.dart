import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_checkout_page.dart';

class ClientPaymentPage extends StatefulWidget {
  final String jobId;
  final String quoteId;

  /// Fallbacks só pra UI (opcionais)
  final String? jobTitle;
  final String? providerName;

  const ClientPaymentPage({
    super.key,
    required this.jobId,
    required this.quoteId,
    this.jobTitle,
    this.providerName,
  });

  @override
  State<ClientPaymentPage> createState() => _ClientPaymentPageState();
}

class _ClientPaymentPageState extends State<ClientPaymentPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  bool navigating = false;
  String? error;

  /// Registro mais recente da view v_client_job_payments (pode ser null se ainda não existe pagamento)
  Map<String, dynamic>? payment;

  /// Quote carregada via view v_client_job_quotes (fonte do preço para liberar botões)
  Map<String, dynamic>? quote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      payment = null;
      quote = null;
    });

    try {
      // 1) Pagamento (view) - pode não existir ainda
      final p = await supabase
          .from('v_client_job_payments')
          .select('''
            payment_id,
            job_id,
            client_id,
            amount_total,
            payment_method,
            gateway,
            gateway_transaction_id,
            status,
            paid_at,
            created_at,
            refund_amount,
            refunded_at,
            gateway_metadata
          ''')
          .eq('job_id', widget.jobId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      Map<String, dynamic>? pMap;
      if (p != null) {
        pMap = (p as Map).cast<String, dynamic>();
      }

      // 2) Quote (view) - deve existir, é a fonte do preço aprovado
      final qRes = await supabase.from('v_client_job_quotes').select('''
        quote_id,
        job_id,
        provider_id,
        approximate_price,
        message,
        created_at,
        provider_name,
        provider_avatar_url,
        provider_rating,
        provider_verified,
        provider_city,
        provider_is_online
      ''').eq('quote_id', widget.quoteId).maybeSingle();

      Map<String, dynamic>? qMap;
      if (qRes != null) {
        qMap = (qRes as Map).cast<String, dynamic>();

        // segurança UX: quote deve pertencer ao job
        if (qMap['job_id'] != widget.jobId) {
          setState(() {
            loading = false;
            error = 'Este orçamento não pertence a este pedido.';
          });
          return;
        }
      } else {
        setState(() {
          loading = false;
          error = 'Orçamento não encontrado.';
        });
        return;
      }

      setState(() {
        payment = pMap;
        quote = qMap;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Erro ao carregar: $e';
      });
    }
  }

  String _prettyPaymentStatus(String raw) {
    switch (raw) {
      case 'paid':
        return 'Pago';
      case 'pending':
        return 'Aguardando confirmação';
      case 'refunded':
        return 'Estornado';
      case 'canceled':
        return 'Cancelado';
      case 'failed':
        return 'Falhou';
      default:
        return raw.isEmpty ? '—' : raw;
    }
  }

  Future<void> _openCheckout(BuildContext context,
      {required String method}) async {
    if (navigating) return;

    setState(() {
      navigating = true;
      error = null;
    });

    try {
      final started = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClientCheckoutPage(
            jobId: widget.jobId,
            quoteId: widget.quoteId,
            jobTitle: widget.jobTitle,
            providerName: widget.providerName,
            initialMethod: method, // 'pix' | 'card'
          ),
        ),
      );

      if (!mounted) return;

      if (started == true) {
        // Recarrega status/valores após iniciar pagamento
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Erro ao abrir checkout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error!)),
      );
    } finally {
      if (mounted) setState(() => navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
      decimalDigits: 2,
    );

    final p = payment;
    final q = quote;

    final title = widget.jobTitle ?? 'Serviço';

    // Nome do prestador vindo da view (melhor que ID)
    final providerNameFromView = (q?['provider_name'] as String?)?.trim();
    final providerId = (q?['provider_id'] as String?) ?? '';

    final providerLabel = widget.providerName ??
        ((providerNameFromView != null && providerNameFromView.isNotEmpty)
            ? providerNameFromView
            : (providerId.isNotEmpty
                ? 'Profissional ${providerId.substring(0, 6)}...'
                : 'Profissional'));

    // Valor: prioriza payment.amount_total (quando já existe), senão quote.approximate_price
    final amountFromPayment = p?['amount_total'];
    final amountFromQuote = q?['approximate_price'];

    final double? amount = (amountFromPayment is num)
        ? amountFromPayment.toDouble()
        : (amountFromQuote is num)
            ? amountFromQuote.toDouble()
            : null;

    final paymentStatusRaw = (p?['status'] as String?) ?? '';
    final paymentStatusLabel = _prettyPaymentStatus(paymentStatusRaw);
    final alreadyPaid = paymentStatusRaw == 'paid';

    final canPay = !loading && !navigating && amount != null && !alreadyPaid;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  left: 8, right: 20, top: 10, bottom: 16),
              color: roxo,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pagamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(error!, textAlign: TextAlign.center),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumo do serviço',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: roxo),
                      ),
                      const SizedBox(height: 10),
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
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: roxo,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Prestador: $providerLabel',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 12),
                            Text(
                              'Valor aprovado: ${amount != null ? currency.format(amount) : '—'}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: roxo,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pagamento: ${paymentStatusRaw.isEmpty ? '—' : paymentStatusLabel}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (alreadyPaid) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            '✅ Este serviço já está pago.\n\n'
                            'O backend deve ter confirmado o pagamento.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _load,
                            child: const Text('Atualizar'),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Método de pagamento',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: roxo),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: canPay
                                    ? () =>
                                        _openCheckout(context, method: 'pix')
                                    : null,
                                child: Opacity(
                                  opacity: canPay ? 1 : 0.5,
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      navigating ? 'Abrindo...' : 'Pix',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: canPay
                                    ? () =>
                                        _openCheckout(context, method: 'card')
                                    : null,
                                child: Opacity(
                                  opacity: canPay ? 1 : 0.5,
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      navigating ? 'Abrindo...' : 'Cartão',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Você será direcionado para o checkout para informar dados do pagador e endereço de cobrança.\n\n'
                            'Após iniciar o pagamento, o status ficará como "Aguardando confirmação".',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
