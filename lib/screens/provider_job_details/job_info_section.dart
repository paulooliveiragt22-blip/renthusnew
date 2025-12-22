import 'package:flutter/material.dart';

class JobInfoSection extends StatelessWidget {
  final String jobCode;
  final String description;
  final String pricingLabel;
  final int? dailyQuantity;

  const JobInfoSection({
    super.key,
    required this.jobCode,
    required this.description,
    required this.pricingLabel,
    this.dailyQuantity,
  });

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações do Serviço',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: roxo,
            ),
          ),
          const SizedBox(height: 16),

          // Layout responsivo: em telas estreitas fica em coluna, em largas fica em linha
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;

              final pedidoCard = _InfoPill(
                title: 'Pedido:',
                value: jobCode.isNotEmpty ? jobCode : '-',
              );

              final modeloValue =
                  (pricingLabel == 'Por diária' && dailyQuantity != null)
                      ? '$pricingLabel · $dailyQuantity diárias'
                      : pricingLabel;

              final modeloCard = _InfoPill(
                title: 'Modelo de contratação:',
                value: modeloValue,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    pedidoCard,
                    const SizedBox(height: 12),
                    modeloCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: pedidoCard),
                  const SizedBox(width: 12),
                  Expanded(child: modeloCard),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          const Text(
            'Descrição do cliente:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          // 🔥 Fotos foram removidas daqui.
          // Agora ficam apenas na JobPhotosSection, em outro card separado.
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String title;
  final String value;

  const _InfoPill({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
