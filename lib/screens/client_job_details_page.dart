import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_payment_page.dart';
import 'chat_page.dart';
import '../repositories/chat_repository.dart';
import '../repositories/job_repository.dart';
import 'client_cancel_job_page.dart';
import 'client_review_page.dart';
import 'open_dispute_page.dart';
import 'client_job_proposal_page.dart';
import 'client_dispute_page.dart';

class ClientJobDetailsPage extends StatefulWidget {
  final String jobId;

  const ClientJobDetailsPage({super.key, required this.jobId});

  @override
  State<ClientJobDetailsPage> createState() => _ClientJobDetailsPageState();
}

class _ClientJobDetailsPageState extends State<ClientJobDetailsPage> {
  final supabase = Supabase.instance.client;
  final chatRepo = ChatRepository();
  final JobRepository _jobRepository = JobRepository();

  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? job;

  /// Propostas (derivadas de v_client_job_quotes)
  List<Map<String, dynamic>> candidates = [];

  /// Disputa
  bool _hasOpenDispute = false; // disputa em andamento (reabre chat)
  bool _hasAnyDispute = false; // já existe alguma reclamação (só 1 por job)

  /// Pagamento
  bool _hasPaid = false;
  Map<String, dynamic>? _payment;

  bool _isResolvingDispute = false;

  final _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  bool _isJobClosedForChat(String status) {
    const closed = [
      'completed',
      'cancelled_by_client',
      'cancelled_by_provider',
      'refunded',
    ];
    return closed.contains(status);
  }

  bool _canAccessDispute(String status) {
    return status == 'completed' || _hasAnyDispute;
  }

  String _fmtDateTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return _dateFormat.format(dt);
    } catch (_) {
      return iso;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _friendlyProviderName(String providerId) {
    if (providerId.isEmpty) return 'Profissional';
    if (providerId.length <= 6) return 'Profissional $providerId';
    return 'Profissional ${providerId.substring(0, 6)}…';
  }

  // ---------------------------------------------------------------------------
  // CARREGAR DADOS (SOMENTE v_jobs_with_dispute_status + views auxiliares)
  // ---------------------------------------------------------------------------

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Faça login novamente para ver os detalhes do pedido.';
        });
        return;
      }

      // 1) Job (detalhe completo) via v_jobs_with_dispute_status
      // ✅ Não usamos scheduled_at no app
      final jobRes = await supabase.from('v_client_jobs').select('''
      id,
      client_id,
      provider_id,
      title,
      description,
      status,
      created_at,
      updated_at,
      job_code,
      status,
      photos
    ''').eq('id', widget.jobId).maybeSingle();

      if (jobRes == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Pedido não encontrado.';
        });
        return;
      }

      final Map<String, dynamic> jobMap =
          Map<String, dynamic>.from(jobRes as Map);

      final String jobId = jobMap['id'].toString();

// 🔒 Segurança extra (opcional, mas ok manter)
      final String clientId = (jobMap['client_id'] ?? '').toString();
      if (clientId.isNotEmpty && clientId != user.id) {
        setState(() {
          isLoading = false;
          errorMessage = 'Você não tem permissão para ver este pedido.';
        });
        return;
      }

      // 2) Flags de disputa (centralizadas na view)
      final bool hasAnyDispute = (jobMap['is_disputed'] == true);
      final bool hasOpenDispute = (jobMap['dispute_open'] == true);

      // 3) Pagamento (último) via v_client_job_payments (order + limit 1)
      bool hasPaid = false;
      Map<String, dynamic>? paymentRow;

      try {
        final pay = await supabase
            .from('v_client_job_payments')
            .select('''
              payment_id,
              job_id,
              amount_total,
              payment_method,
              gateway,
              gateway_transaction_id,
              status,
              paid_at,
              created_at,
              refund_amount,
              refunded_at
            ''')
            .eq('job_id', jobId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (pay != null) {
          paymentRow = Map<String, dynamic>.from(pay as Map);
          hasPaid = (paymentRow['status']?.toString() == 'paid');
        } else {
          // fallback com base no payment_status do job
          hasPaid = (jobMap['payment_status']?.toString() == 'paid');
        }
      } catch (_) {
        // fallback com base no payment_status do job
        hasPaid = (jobMap['payment_status']?.toString() == 'paid');
      }

      // 4) Propostas (quotes) via v_client_job_quotes
      final quotesRes = await supabase
          .from('v_client_job_quotes')
          .select(
              'quote_id, job_id, provider_id, approximate_price, message, created_at')
          .eq('job_id', jobId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> quotesList =
          List<Map<String, dynamic>>.from(quotesRes as List<dynamic>);

      final String? approvedProviderId = jobMap['provider_id'] as String?;
      final bool hasApprovedProvider = approvedProviderId != null;

      final List<Map<String, dynamic>> finalCandidates = [];

      for (final q in quotesList) {
        final providerId = (q['provider_id'] ?? '').toString();
        if (providerId.isEmpty) continue;

        // Se já tem prestador aprovado, só mantém a proposta dele
        if (hasApprovedProvider && providerId != approvedProviderId) continue;

        finalCandidates.add({
          'provider_id': providerId,
          'provider_name': _friendlyProviderName(providerId),
          'provider_avatar_url': null,
          'created_at': q['created_at'],
          'quote_id': q['quote_id'], // ✅ essencial
          'approximate_price': q['approximate_price'],
          'quote_message': q['message'],
          'client_status': hasApprovedProvider ? 'approved' : 'pending',
        });
      }

      if (!mounted) return;
      setState(() {
        job = jobMap;
        candidates = finalCandidates;
        _hasAnyDispute = hasAnyDispute;
        _hasOpenDispute = hasOpenDispute;
        _hasPaid = hasPaid;
        _payment = paymentRow;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar detalhes do pedido (cliente): $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Erro ao carregar os detalhes do pedido.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // AÇÕES DO CLIENTE SOBRE PROPOSTAS (aprovar / pagamento)
  // ---------------------------------------------------------------------------

  Future<void> _approveCandidate(Map<String, dynamic> candidate) async {
    if (job == null) return;

    final String jobStatus = (job!['status'] as String?) ?? '';

    final String providerId = (candidate['provider_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    final String? quoteId = candidate['quote_id']?.toString();
    if (quoteId == null || quoteId.isEmpty) {
      _snack('Orçamento inválido para este prestador.');
      return;
    }

    // trava duplicado (lado app)
    if (_hasPaid || (job?['payment_status']?.toString() == 'paid')) {
      _snack('Pagamento já registrado para este pedido.');
      return;
    }

    // job em disputa não abre pagamento
    if (jobStatus == 'dispute' || _hasOpenDispute) {
      _snack(
        'Este pedido está em análise de disputa. '
        'Não é possível confirmar um novo pagamento.',
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final String providerName =
          (candidate['provider_name'] as String?) ?? 'Prestador';
      final String jobTitle = (job?['title'] as String?) ??
          (job?['description'] as String?) ??
          'Serviço';

      final bool? paymentDone = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClientPaymentPage(
            jobId: job!['id'].toString(),
            quoteId: quoteId, // obrigatório
            jobTitle: jobTitle,
            providerName: providerName,
          ),
        ),
      );

      if (paymentDone != true) {
        if (!mounted) return;
        setState(() => isLoading = false);
        _snack('Pagamento não foi concluído. Nada foi alterado.');
        return;
      }

      await _loadData();

      if (!mounted) return;

      _snack(
        'Pagamento confirmado! Prestador aprovado. '
        'Você já pode conversar com ele no chat.',
      );
    } catch (e) {
      debugPrint('Erro ao aprovar candidato (pagamento): $e');
      if (!mounted) return;
      _snack('Erro ao aprovar prestador: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // CHAT
  // ---------------------------------------------------------------------------

  Future<void> _openChatForApprovedCandidate(
    Map<String, dynamic> candidate,
  ) async {
    if (job == null) {
      _snack('Não foi possível identificar o pedido.');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _snack('Faça login novamente para acessar o chat.');
      return;
    }

    final jobId = job!['id'].toString();
    final clientId = job!['client_id'].toString();
    final providerId = (candidate['provider_id'] ?? '').toString();
    final status = (job!['status'] as String?) ?? '';

    if (providerId.isEmpty) {
      _snack('Não foi possível identificar o prestador.');
      return;
    }

    final bool isJobClosed = _isJobClosedForChat(status);
    final bool isChatLocked = isJobClosed && !_hasOpenDispute;

    try {
      final conv = await chatRepo.upsertConversationForJob(
        jobId: jobId,
        clientId: clientId,
        providerId: providerId,
      );

      if (conv == null || conv['id'] == null) {
        _snack('Não foi possível abrir a conversa. Tente novamente.');
        return;
      }

      final conversationId = conv['id'].toString();
      final jobTitle = (job!['title'] as String?) ??
          (job!['description'] as String?) ??
          'Conversas do pedido';
      final otherUserName =
          (candidate['provider_name'] as String?) ?? 'Profissional';

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            jobTitle: jobTitle,
            otherUserName: otherUserName,
            currentUserId: user.id,
            currentUserRole: 'client',
            isChatLocked: isChatLocked,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao abrir o chat: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PROPOSTA
  // ---------------------------------------------------------------------------

  Future<void> _showQuoteDialogForCandidate(
    Map<String, dynamic> candidate,
  ) async {
    if (job == null) return;

    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientJobProposalPage(
          job: job!,
          candidate: candidate,
          onApprove: _approveCandidate,
        ),
      ),
    );

    if (changed == true) {
      await _loadData();
    }
  }

  // ---------------------------------------------------------------------------
  // AÇÕES DO JOB
  // ---------------------------------------------------------------------------

  bool _canClientCancel(Map<String, dynamic> j) {
    final status = j['status'] as String? ?? '';
    const blocked = [
      'in_progress',
      'completed',
      'cancelled_by_client',
      'cancelled_by_provider',
      'refunded',
      'dispute',
    ];
    return !blocked.contains(status);
  }

  Future<void> _goToCancelPage() async {
    if (job == null) return;

    final bool? cancelled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CancelJobPage(
          jobId: job!['id'].toString(),
          role: 'client',
        ),
      ),
    );

    if (cancelled == true) {
      await _loadData();
      if (!mounted) return;
      _snack(
        'Pedido cancelado com sucesso. '
        'Se houve pagamento, o estorno será processado em breve.',
      );
    }
  }

  Future<void> _goToReviewPage() async {
    if (job == null) return;
    final providerId = job!['provider_id']?.toString();
    if (providerId == null) return;

    final bool? done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientReviewPage(
          jobId: job!['id'].toString(),
          providerId: providerId,
        ),
      ),
    );

    if (done == true) {
      _snack('Avaliação enviada!');
    }
  }

  Future<void> _goToDisputePage() async {
    if (job == null) return;

    final String jobId = job!['id'].toString();

    if (_hasAnyDispute) {
      final bool? changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClientDisputePage(jobId: jobId),
        ),
      );

      if (changed == true) await _loadData();
      return;
    }

    final bool? opened = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OpenDisputePage(jobId: jobId),
      ),
    );

    if (opened == true) {
      await _loadData();
      if (!mounted) return;
      _snack(
        'Reclamação registrada. O prestador será notificado para entrar em contato.',
      );
    }
  }

  Future<void> _onResolveDisputePressed() async {
    if (job == null) return;

    setState(() => _isResolvingDispute = true);

    try {
      final jobId = job!['id'].toString();

      await _jobRepository.resolveDisputeForJob(jobId);

      await _loadData();

      if (!mounted) return;

      _snack('Obrigado pelo retorno! Problema marcado como resolvido.');
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao marcar problema como resolvido: $e');
    } finally {
      if (mounted) setState(() => _isResolvingDispute = false);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: isLoading
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
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 8, right: 20, top: 10, bottom: 16),
      color: const Color(0xFF3B246B),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Detalhes do Pedido',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (job == null) {
      return const Center(child: Text('Pedido não encontrado.'));
    }

    final j = job!;
    final String title = (j['title'] as String?) ?? 'Serviço';
    final String description = (j['description'] as String?) ?? 'Sem descrição';

    // ✅ scheduled_at não é usado mais
    final createdAt = j['created_at']?.toString();
    final createdLabel = createdAt != null && createdAt.isNotEmpty
        ? _fmtDateTime(createdAt)
        : '';

    final String dateLabel = createdLabel.isNotEmpty
        ? 'Criado em: $createdLabel'
        : 'Data a combinar';

    const String pricingText = 'Orçamento';

    final String jobStatus = j['status'] as String? ?? '';
    final bool canCancel = _canClientCancel(j);
    final bool canReview = jobStatus == 'completed' && j['provider_id'] != null;

    final bool canOpenDispute = jobStatus == 'completed' && !_hasAnyDispute;
    final bool canResolveDispute = jobStatus == 'dispute' && _hasOpenDispute;

    // payment card (usa o registro do payments quando existir, senão usa fields do job)
    final String? paymentStatus =
        _payment?['status']?.toString() ?? j['payment_status']?.toString();
    final String? gatewayTx = _payment?['gateway_transaction_id']?.toString();
    final double? amountTotal = (_payment?['amount_total'] as num?)?.toDouble();
    final double? refundAmount =
        (_payment?['refund_amount'] as num?)?.toDouble() ??
            (j['last_refund_amount'] as num?)?.toDouble();

    final String? refundedAt = _payment?['refunded_at']?.toString() ??
        j['last_refunded_at']?.toString();
    final String? paidAt =
        _payment?['paid_at']?.toString() ?? j['paid_at']?.toString();

    Widget paymentCard() {
      // mostra card se tiver sinal de pagamento (pelo menos payment_status)
      final bool hasPaymentInfo =
          paymentStatus != null && paymentStatus!.trim().isNotEmpty;

      if (_payment == null && !hasPaymentInfo) return const SizedBox.shrink();

      String line1 = 'Status: ${paymentStatus ?? '-'}';

      String line2 = '';
      if (amountTotal != null && amountTotal > 0) {
        line2 = 'Total: ${_currencyBr.format(amountTotal)}';
      }

      String line3 = '';
      if (gatewayTx != null && gatewayTx.isNotEmpty) {
        line3 = 'Recibo/ID: $gatewayTx';
      }

      String line4 = '';
      if ((paymentStatus == 'paid') && paidAt != null) {
        final paidTxt = _fmtDateTime(paidAt);
        line4 = paidTxt.isNotEmpty ? 'Pago em: $paidTxt' : '';
      } else if ((paymentStatus == 'refunded') &&
          refundAmount != null &&
          refundAmount > 0) {
        final refTxt = _currencyBr.format(refundAmount);
        final refDt = refundedAt != null ? _fmtDateTime(refundedAt) : '';
        line4 = refDt.isNotEmpty
            ? 'Estornado em: $refDt • $refTxt'
            : 'Estornado: $refTxt';
      }

      final lines = [
        line1,
        if (line2.isNotEmpty) line2,
        if (line3.isNotEmpty) line3,
        if (line4.isNotEmpty) line4
      ];

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pagamento',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  t,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Disputa card simples (com base na view mãe)
    Widget disputeInfoCard() {
      if (!_hasAnyDispute) return const SizedBox.shrink();

      final reason = (j['dispute_reason'] as String?) ?? '';
      final openedAt = (j['dispute_opened_at']?.toString());
      final openedLabel =
          openedAt != null && openedAt.isNotEmpty ? _fmtDateTime(openedAt) : '';

      final statusText = _hasOpenDispute ? 'Em análise' : 'Encerrada';

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reclamação',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $statusText',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            if (openedLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Aberta em: $openedLabel',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            if (reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Motivo: $reason',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações do Pedido',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 12),
          _infoCard(label: 'Serviço', value: title),
          _infoCard(label: 'Modelo de contratação', value: pricingText),
          _infoCard(label: 'Data/Hora', value: dateLabel),
          _infoCard(label: 'Descrição do serviço', value: description),
          paymentCard(),
          disputeInfoCard(),
          const SizedBox(height: 16),
          const Text(
            'Propostas de profissionais',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 8),
          if (candidates.isEmpty)
            const Text(
              'Ainda não há profissionais interessados neste pedido.\n'
              'Assim que alguém enviar uma proposta, aparecerá aqui.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: candidates
                  .map((c) => _buildCandidateCard(context, c))
                  .toList(),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Dica:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Você pode ver os detalhes da proposta de cada profissional, '
            'aprovar quem achar melhor para seguir para o pagamento.',
            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (canCancel ||
              canReview ||
              canOpenDispute ||
              canResolveDispute ||
              _hasAnyDispute) ...[
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Ações do pedido',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            if (canCancel)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _goToCancelPage,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar este pedido'),
                ),
              ),
            if (canReview)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToReviewPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B246B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Avaliar profissional'),
                ),
              ),
            if (canOpenDispute) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _goToDisputePage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Abrir reclamação'),
                ),
              ),
            ],
            if (_hasAnyDispute) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goToDisputePage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B246B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon:
                      const Icon(Icons.report_gmailerrorred_outlined, size: 18),
                  label: const Text(
                    'Ver reclamação',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            if (_canAccessDispute(jobStatus))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientDisputePage(
                          jobId: job!['id'].toString(),
                        ),
                      ),
                    );

                    if (changed == true) {
                      await _loadData(); // atualiza status ao voltar
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.report_gmailerrorred_outlined),
                  label: Text(
                    _hasAnyDispute ? 'Ver reclamação' : 'Abrir reclamação',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            if (canResolveDispute) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isResolvingDispute ? null : _onResolveDisputePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0DAA00),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isResolvingDispute
                        ? 'Atualizando...'
                        : 'Problema resolvido',
                  ),
                ),
              ),
            ],
            if (!_hasOpenDispute && _hasAnyDispute) ...[
              const SizedBox(height: 6),
              const Text(
                'Já existe uma reclamação registrada para este pedido.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            if (jobStatus == 'dispute') ...[
              const SizedBox(height: 6),
              const Text(
                'Este pedido está em análise de disputa. '
                'Não é possível cancelar ou registrar novo pagamento enquanto a análise estiver aberta.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoCard({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF3B246B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateCard(BuildContext context, Map<String, dynamic> c) {
    final providerName = (c['provider_name'] as String?) ?? 'Prestador';
    final clientStatus = (c['client_status'] as String?) ?? 'pending';
    final createdAt = c['created_at']?.toString();
    final approxPrice = (c['approximate_price'] as num?)?.toDouble();

    final String? jobProviderId = job?['provider_id'] as String?;
    final bool isApprovedProvider = jobProviderId != null &&
        (c['provider_id']?.toString() == jobProviderId);

    final String jobStatus = job?['status'] as String? ?? '';
    final bool isJobClosed = _isJobClosedForChat(jobStatus);
    final bool isChatLocked = isJobClosed && !_hasOpenDispute;

    String statusLabel;
    Color statusColor;

    switch (clientStatus) {
      case 'approved':
        statusLabel = 'Aprovado';
        statusColor = const Color(0xFF0DAA00);
        break;
      case 'rejected':
        statusLabel = 'Recusado';
        statusColor = Colors.grey;
        break;
      default:
        statusLabel = 'Pendente';
        statusColor = Colors.grey;
    }

    if (isApprovedProvider) {
      statusLabel = 'Aprovado';
      statusColor = const Color(0xFF0DAA00);
    }

    final bool canShowChat = isApprovedProvider && !isChatLocked;

    String createdLabel = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        createdLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showQuoteDialogForCandidate(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    providerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (approxPrice != null)
              Text(
                'Valor: ${_currencyBr.format(approxPrice)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3B246B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (createdLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Proposta enviada em: $createdLabel',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              'Toque para ver a proposta completa deste profissional.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (canShowChat) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _openChatForApprovedCandidate(c),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B246B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text(
                    'Ir para o chat',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
