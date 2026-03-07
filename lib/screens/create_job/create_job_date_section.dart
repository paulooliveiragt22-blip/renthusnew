import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

class CreateJobDateSection extends StatelessWidget {

  const CreateJobDateSection({
    super.key,
    required this.selectedDateLabel,
    required this.onToday,
    required this.onTomorrow,
    required this.onChooseDate,
  });
  final String? selectedDateLabel;
  final VoidCallback onToday;
  final VoidCallback onTomorrow;
  final Future<void> Function() onChooseDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Para quando você precisa?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _DateChip(
              label: 'Hoje',
              isSelected: selectedDateLabel == 'Hoje',
              onTap: onToday,
            ),
            const SizedBox(width: 8),
            _DateChip(
              label: 'Amanhã',
              isSelected: selectedDateLabel == 'Amanhã',
              onTap: onTomorrow,
            ),
            const SizedBox(width: 8),
            _DateChip(
              label: 'Escolher data',
              isSelected: selectedDateLabel != null &&
                  selectedDateLabel != 'Hoje' &&
                  selectedDateLabel != 'Amanhã',
              onTap: () => onChooseDate(),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {

  const _DateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: kRoxo,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => onTap(),
    );
  }
}
