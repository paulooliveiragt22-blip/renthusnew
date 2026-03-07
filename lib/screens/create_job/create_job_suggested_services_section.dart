import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

class CreateJobSuggestedServicesSection extends StatelessWidget {

  const CreateJobSuggestedServicesSection({
    super.key,
    required this.suggestedProfessionals,
    required this.selectedProfessional,
    required this.autoSuggestedProfessional,
    required this.showSuggestedHelperText,
    required this.hasUserSelectedProfessional,
    required this.onSelectProfessional,
  });
  final List<String> suggestedProfessionals;
  final String? selectedProfessional;
  final String? autoSuggestedProfessional;
  final bool showSuggestedHelperText;
  final bool hasUserSelectedProfessional;
  final ValueChanged<String?> onSelectProfessional;

  @override
  Widget build(BuildContext context) {
    if (suggestedProfessionals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Serviços sugeridos:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: suggestedProfessionals
              .map(
                (prof) => ChoiceChip(
                  label: Text(
                    prof,
                    style: TextStyle(
                      fontWeight: selectedProfessional == prof
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selectedProfessional == prof
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  selected: selectedProfessional == prof,
                  selectedColor: kRoxo,
                  backgroundColor: Colors.grey.shade200,
                  onSelected: (selected) {
                    onSelectProfessional(selected ? prof : null);
                  },
                ),
              )
              .toList(),
        ),
        if (autoSuggestedProfessional != null &&
            showSuggestedHelperText &&
            !hasUserSelectedProfessional) ...[
          const SizedBox(height: 6),
          Text(
            'Serviço sugerido: $autoSuggestedProfessional',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kRoxo,
            ),
          ),
        ],
        if (selectedProfessional != null && hasUserSelectedProfessional) ...[
          const SizedBox(height: 4),
          Text(
            'Serviço selecionado: $selectedProfessional',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kRoxo,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
