import 'package:flutter/material.dart';

class JobAddressSection extends StatelessWidget {
  final String addressText;         // Texto final formatado do endereço
  final bool showAddress;           // Se o endereço deve aparecer (match feito + status permitido)
  final VoidCallback? onOpenMap;    // Callback para abrir o mapa

  const JobAddressSection({
    super.key,
    required this.addressText,
    required this.showAddress,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showAddress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Endereço protegido.\n'
          'Ele será liberado somente após o cliente confirmar você no serviço.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      );
    }

    return Container(
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
            'Endereço do cliente',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 6),

          // Endereço formatado
          Text(
            addressText,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Ver localização no mapa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B246B),
                side: const BorderSide(color: Color(0xFF3B246B)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
