import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  bool loading = true;
  bool paying = false;
  String? error;
  Map<String, dynamic>? job;
  Map<String, dynamic>? quote;

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      job = null;
      quote = null;
    });

    final supabase = ref.read(supabaseProvider);

    try {
      final j = await supabase
          .from('jobs')
          .select('id, title, status, provider_id, payment_status, price')
          .eq('id', widget.jobId)
          .maybeSingle();

      if (j == null) {
        setState(() {
          loading = false;
          error = 'Pedido não encontrado.';
        });
        return;
      }

      final q = await supabase
          .from('job_quotes')
          .select(
              'id, job_id, provider_id, approximate_price, is_accepted, created_at',)
          .eq('id', widget.quoteId)
          .maybeSingle();

      if (q == null) {
        setState(() {
          loading = false;
          error = 'Orçamento não encontrado.';
        });
        return;
      }

      if (q['job_id'] != widget.jobId) {
        setState(() {
          loading = false;
          error = 'Este orçamento não pertence a este pedido.';
        });
        return;
      }

      setState(() {
        job = (j as Map).cast<String, dynamic>();
        quote = (q as Map).cast<String, dynamic>();
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Erro ao carregar: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _startPayment(BuildContext context,
      {required String paymentMethod,}) async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Faça login novamente para concluir o pagamento.'),),
      );
      return;
    }

    if (paying) return;

    setState(() {
      paying = true;
      error = null;
    });

    try {
      final res = await supabase.functions.invoke(
        'create-payment',
        body: {
          'job_id': widget.jobId,
          'quote_id': widget.quoteId,
          'payment_method': paymentMethod,
        },
      );

      final data = res.data;
      if (res.status != 200 || data == null || data['ok'] != true) {
        throw Exception(data?['error'] ?? 'Falha ao iniciar pagamento');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Pagamento iniciado (pending). Aguardando confirmação...',),),
      );

      await _load();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Erro ao processar pagamento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error!)),
      );
    } finally {
      if (mounted) setState(() => paying = false);
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

    final j = job;
    final q = quote;

    final title = (j?['title'] as String?) ?? widget.jobTitle ?? 'Serviço';
    final providerId = (q?['provider_id'] as String?) ?? '';
    final providerLabel = widget.providerName ??
        (providerId.isNotEmpty ? providerId : 'Profissional escolhido');

    final amountNum = q?['approximate_price'];
    final double? amount = (amountNum is num) ? amountNum.toDouble() : null;

    final paymentStatus = (j?['payment_status'] as String?) ?? '';
    final alreadyPaid = paymentStatus == 'paid';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  left: 8, right: 20, top: 10, bottom: 16,),
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
                            color: roxo,),
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
                                  color: roxo,),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Prestador: $providerLabel',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Valor aprovado: ${amount != null ? currency.format(amount) : '—'}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: roxo,),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pagamento: ${paymentStatus.isEmpty ? '—' : paymentStatus}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54,),
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
                            'O backend já deve ter definido provider_id, atualizado status do job e preenchido valores no jobs.',
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
                        const SizedBox(height: 18),
                      ] else ...[
                        const Text(
                          'Método de pagamento',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: roxo,),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: (paying || amount == null)
                                    ? null
                                    : () => _startPayment(context,
                                        paymentMethod: 'pix',),
                                child: Opacity(
                                  opacity: (paying || amount == null) ? 0.5 : 1,
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      paying
                                          ? 'Processando...'
                                          : 'Pix (simulado)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: (paying || amount == null)
                                    ? null
                                    : () => _startPayment(context,
                                        paymentMethod: 'card',),
                                child: Opacity(
                                  opacity: (paying || amount == null) ? 0.5 : 1,
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      paying
                                          ? 'Processando...'
                                          : 'Cartão (simulado)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,),
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
                            'Nesta versão estamos apenas iniciando o pagamento (pending).\n\n'
                            'O app não grava em payments nem altera jobs.\n'
                            'Quando o backend mudar o payment para "paid", o banco faz todo o resto automaticamente.',
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
