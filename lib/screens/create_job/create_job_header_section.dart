import 'package:flutter/material.dart';

const _kRoxo = Color(0xFF3B246B);
const _kCinzaBar = Color(0xFFE5E1EC);
const _kGreen = Color(0xFF0DAA00);

class CreateJobHeaderSection extends StatelessWidget {
  /// 0 = Serviço, 1 = Local
  final int currentStep;

  /// Callback opcional para voltar etapas
  final ValueChanged<int>? onStepTap;

  const CreateJobHeaderSection({
    super.key,
    required this.currentStep,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),

        // puxador
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(999),
          ),
        ),

        const SizedBox(height: 16),

        // barra de progresso (2 etapas)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 3,
            child: Row(
              children: List.generate(2, (index) {
                final bool isActive = index <= currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: index == 1 ? 0 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? _kGreen : _kCinzaBar,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // títulos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStepTitle(
                index: 0,
                label: 'Serviço',
                isCurrent: currentStep == 0,
                onTap: onStepTap,
              ),
              _buildStepTitle(
                index: 1,
                label: 'Local',
                isCurrent: currentStep == 1,
                onTap: onStepTap,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStepTitle({
    required int index,
    required String label,
    required bool isCurrent,
    ValueChanged<int>? onTap,
  }) {
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
      color: isCurrent ? _kRoxo : Colors.grey.shade600,
    );

    if (onTap == null) {
      return Expanded(
        child: Center(child: Text(label, style: textStyle)),
      );
    }

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Text(label, style: textStyle),
          ),
        ),
      ),
    );
  }
}
