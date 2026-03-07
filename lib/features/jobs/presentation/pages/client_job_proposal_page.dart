import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:renthus/screens/provider_public_profile_page.dart';

class ClientJobProposalPage extends StatelessWidget {

  const ClientJobProposalPage({
    super.key,
    required this.job,
    required this.candidate,
    required this.onApprove,
    this.payment,
  });
  final Map<String, dynamic> job;
  final Map<String, dynamic> candidate;
  final Future<void> Function(Map<String, dynamic>) onApprove;
  final Map<String, dynamic>? payment;

  static final _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final String jobTitle = (job['description'] as String?) ??
        (job['title'] as String?) ??
        'Serviço';

    final String jobStatus = job['status'] as String? ?? '';

    final String providerName =
        candidate['provider_name'] as String? ?? 'Profissional';
    final double? providerRating =
        (candidate['provider_rating'] as num?)?.toDouble();

    final double? suggestedPrice =
        (candidate['approximate_price'] as num?)?.toDouble();

    final String? message = (candidate['quote_message'] as String?) ??
        (candidate['message'] as String?);

    final bool isJobApproved =
        jobStatus == 'accepted' || jobStatus == 'completed';

    final bool isJobCancelled = [
      'cancelled_by_client',
      'cancelled_by_provider',
      'refunded',
    ].contains(jobStatus);

    final bool isJobLocked = isJobApproved || isJobCancelled;

    final double totalToPay = suggestedPrice ?? 0.0;

    final String scheduleText = _formatProposalSchedule(candidate);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Resumo do pedido'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final pid = candidate['provider_id']?.toString();
                              if (pid != null && pid.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProviderPublicProfilePage(providerId: pid),
                                  ),
                                );
                              }
                            },
                            child: _infoRow(
                              label: 'Profissional',
                              value: providerRating != null && providerRating > 0
                                  ? '$providerName ★ ${providerRating.toStringAsFixed(1)}'
                                  : providerName,
                              valueStyle: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3B246B),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF3B246B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _infoRow(
                            label: 'Descrição do serviço',
                            value: jobTitle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Proposta do profissional'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                            label: 'Valor sugerido',
                            value: suggestedPrice != null
                                ? _currencyBr.format(suggestedPrice)
                                : 'Não informado',
                          ),
                          if (scheduleText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _infoRow(
                              label: 'Agendamento',
                              value: scheduleText,
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            'Observações do profissional',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B246B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (message == null || message.trim().isEmpty)
                                ? 'O profissional não adicionou observações.'
                                : message,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle(
                      isJobApproved
                          ? 'Comprovante de pagamento'
                          : 'Resumo antes do pagamento',
                    ),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isJobApproved) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Color(0xFF0DAA00), size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pagamento confirmado',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0DAA00),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              label: 'Valor pago',
                              value: _currencyBr.format(
                                (payment?['amount_total'] as num?)?.toDouble() ??
                                    totalToPay,
                              ),
                              valueStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B246B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _infoRow(
                              label: 'Forma de pagamento',
                              value: 'PIX',
                            ),
                            if (payment?['paid_at'] != null) ...[
                              const SizedBox(height: 4),
                              _infoRow(
                                label: 'Data do pagamento',
                                value: _formatDate(
                                  payment!['paid_at'].toString().split('T').first,
                                ),
                              ),
                            ],
                            if (payment?['gateway_transaction_id'] != null &&
                                (payment!['gateway_transaction_id'] as String)
                                    .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _infoRow(
                                label: 'N.° do pedido',
                                value: payment!['gateway_transaction_id']
                                    .toString(),
                              ),
                            ],
                          ] else ...[
                            _infoRow(
                              label: 'Valor total',
                              value: _currencyBr.format(totalToPay),
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B246B),
                              ),
                              valueStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B246B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ao continuar, você será direcionado para a tela de pagamento. '
                              'O profissional será confirmado somente após o pagamento aprovado.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isJobApproved) _buildAddressSection(),
                  ],
                ),
              ),
            ),
            if (!isJobLocked) _buildBottomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 8, right: 16, top: 10, bottom: 14),
      color: const Color(0xFF3B246B),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Text(
            'Proposta do profissional',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3B246B),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'A combinar';
    try {
      final d = DateTime.parse(iso.split('T').first);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _formatDuration(dynamic minutes) {
    final m = (minutes is num) ? minutes.toInt() : int.tryParse('$minutes') ?? 0;
    final h = m ~/ 60;
    final min = m % 60;
    if (h > 0 && min > 0) return '${h}h ${min}min';
    if (h > 0) return '${h}h';
    return '${min}min';
  }

  static String _formatProposalSchedule(Map<String, dynamic> candidate) {
    final startRaw = candidate['proposed_start_at']?.toString();
    final endRaw = candidate['proposed_end_at']?.toString();

    DateTime? startAt;
    DateTime? endAt;
    if (startRaw != null && startRaw.isNotEmpty) {
      startAt = DateTime.tryParse(startRaw);
    }
    if (endRaw != null && endRaw.isNotEmpty) {
      endAt = DateTime.tryParse(endRaw);
    }

    if (startAt != null && endAt != null) {
      final s = startAt.toLocal();
      final e = endAt.toLocal();

      final startStr =
          '${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')} às '
          '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';

      final sameDay =
          s.year == e.year && s.month == e.month && s.day == e.day;
      final endStr = sameDay
          ? '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}'
          : '${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')} às '
              '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';

      final diff = e.difference(s);
      final totalMinutes = diff.inMinutes;
      final days = totalMinutes ~/ (24 * 60);
      final hours = (totalMinutes % (24 * 60)) ~/ 60;
      final minutes = totalMinutes % 60;

      final parts = <String>[];
      if (days > 0) parts.add('$days dia${days > 1 ? 's' : ''}');
      if (hours > 0) parts.add('${hours}h');
      if (minutes > 0) parts.add('${minutes}min');

      final durationStr = parts.isEmpty ? '' : ' (${parts.join(' ')})';
      return '$startStr — $endStr$durationStr';
    }

    final date = candidate['proposed_date']?.toString();
    final start = candidate['proposed_start_time']?.toString();
    final end = candidate['proposed_end_time']?.toString();

    if ((date == null || date.isEmpty) &&
        (start == null || start.isEmpty) &&
        (end == null || end.isEmpty)) {
      return '';
    }

    return '${date ?? ''} das ${start ?? '--:--'} às ${end ?? '--:--'}';
  }

  Widget _infoRow({
    required String label,
    required String value,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: labelStyle ??
                const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B246B),
                ),
          ),
          TextSpan(
            text: value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    final street = job['address_street']?.toString() ?? '';
    final number = job['address_number']?.toString() ?? '';
    final district = job['address_district']?.toString() ?? '';
    final city = job['address_city']?.toString() ?? '';
    final state = job['address_state']?.toString() ?? '';
    final zipcode = job['address_zipcode']?.toString() ?? '';

    if (street.isEmpty && city.isEmpty) return const SizedBox.shrink();

    final line1 = [street, number].where((s) => s.isNotEmpty).join(', ');
    final line2 = [district, city, state].where((s) => s.isNotEmpty).join(' — ');
    final cepLine = zipcode.isNotEmpty ? 'CEP: $zipcode' : '';
    final parts = [line1, line2, cepLine].where((s) => s.isNotEmpty).join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        _sectionTitle('Endereço do serviço'),
        const SizedBox(height: 8),
        _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Color(0xFF3B246B), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parts,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await onApprove(candidate);
            if (context.mounted) Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B246B),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Continuar para o pagamento',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
