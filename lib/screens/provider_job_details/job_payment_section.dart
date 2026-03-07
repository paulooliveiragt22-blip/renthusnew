import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class JobPaymentApprovedSection extends StatelessWidget {

  const JobPaymentApprovedSection({
    super.key,
    required this.job,
    required this.onOpenMap,
  });
  final Map<String, dynamic> job;
  final void Function(Map<String, dynamic>) onOpenMap;

  bool _shouldShowAddress(String status) {
    // Mesma lógica básica: não mostra em estados finais / disputa
    if (status == 'completed' ||
        status == 'cancelled' ||
        status.startsWith('cancelled_') ||
        status == 'dispute' ||
        status == 'dispute_resolved') {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final currencyBr = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
      decimalDigits: 2,
    );

    final String status = job['status'] as String? ?? '';

    final bool showAddress = _shouldShowAddress(status);

    final double? approvedPrice = (job['price'] as num?)?.toDouble() ??
        (job['daily_total'] as num?)?.toDouble() ??
        (job['client_budget'] as num?)?.toDouble();

    final scheduledStr = job['scheduled_at'] as String?;
    String dateLabel = 'Data a combinar';

    if (scheduledStr != null) {
      try {
        final dt = DateTime.parse(scheduledStr).toLocal();
        dateLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            'às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // Montagem do endereço
    final street = (job['address_street'] as String?)?.trim();
    final number = (job['address_number'] as String?)?.trim();
    final district = (job['address_district'] as String?)?.trim();
    final city = (job['city'] as String?)?.trim();

    String addressText = 'Endereço do cliente não disponível';
    final line1 = [
      if (street != null && street.isNotEmpty) street,
      if (number != null && number.isNotEmpty) number,
    ].join(', ');

    final line2 = [
      if (district != null && district.isNotEmpty) district,
      if (city != null && city.isNotEmpty) city,
    ].join(' - ');

    if (line1.isNotEmpty || line2.isNotEmpty) {
      addressText = [line1, line2].where((s) => s.isNotEmpty).join('\n');
    }

    final valueText = approvedPrice != null && approvedPrice > 0
        ? currencyBr.format(approvedPrice)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner verde
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0DAA00),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pagamento aprovado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Card branco
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
              const Text(
                'Resumo do pedido',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B246B),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Valor aprovado',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Data da execução',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ENDEREÇO – só aparece quando permitido
              if (showAddress) ...[
                const Text(
                  'Endereço do cliente',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B246B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  addressText,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => onOpenMap(job),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Ver localização no mapa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B246B),
                      side: const BorderSide(color: Color(0xFF3B246B)),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
