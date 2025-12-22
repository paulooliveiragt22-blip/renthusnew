import 'package:flutter/material.dart';

class JobHeaderSection extends StatelessWidget {
  final VoidCallback onBack;

  const JobHeaderSection({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 8, right: 20, top: 10, bottom: 16),
      color: const Color(0xFF3B246B),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          const Text(
            'Detalhes do Serviço',
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
}
