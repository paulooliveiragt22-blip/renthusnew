import 'package:flutter/material.dart';

class JobScheduleSection extends StatelessWidget {

  const JobScheduleSection({
    super.key,
    required this.isAssigned,
    required this.isCandidate,
    required this.requestedLabel,
    required this.selectedScheduleLabel,
    required this.dateChoice,
    required this.onTapOption,
  });
  final bool isAssigned;
  final bool isCandidate;
  final String requestedLabel;
  final String selectedScheduleLabel;
  final String? dateChoice;
  final void Function(String option) onTapOption;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Data/Hora solicitada: ',
                  style: TextStyle(
                    color: Color(0xFF3B246B),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: requestedLabel,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!isAssigned && !isCandidate) ...[
            const Text(
              'Escolha uma opção e selecione o horário em que você pode atender:',
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onTapOption('confirm'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: dateChoice == 'confirm'
                            ? const Color(0xFF3B246B)
                            : Colors.grey.shade400,
                      ),
                      foregroundColor: dateChoice == 'confirm'
                          ? const Color(0xFF3B246B)
                          : Colors.black87,
                    ),
                    child: const Text(
                      'Confirmar horário',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onTapOption('change'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: dateChoice == 'change'
                            ? const Color(0xFF3B246B)
                            : Colors.grey.shade400,
                      ),
                      foregroundColor: dateChoice == 'change'
                          ? const Color(0xFF3B246B)
                          : Colors.black87,
                    ),
                    child: const Text(
                      'Sugerir outro horário',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selectedScheduleLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
