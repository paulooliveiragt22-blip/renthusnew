import 'package:flutter/material.dart';

/// Seção de agendamento na proposta do prestador.
/// Usa data+hora início e data+hora fim; duração é calculada automaticamente.
const _kRoxo = Color(0xFF3B246B);

class ProviderQuoteScheduleSection extends StatelessWidget {
  const ProviderQuoteScheduleSection({
    super.key,
    required this.hasFlexibleSchedule,
    required this.clientScheduledDate,
    required this.clientStartTime,
    required this.clientEndTime,
    required this.proposedStartAt,
    required this.proposedEndAt,
    required this.onStartAtChanged,
    required this.onEndAtChanged,
  });

  final bool hasFlexibleSchedule;
  final DateTime? clientScheduledDate;
  final String? clientStartTime;
  final String? clientEndTime;
  final DateTime? proposedStartAt;
  final DateTime? proposedEndAt;
  final ValueChanged<DateTime?> onStartAtChanged;
  final ValueChanged<DateTime?> onEndAtChanged;

  int? get estimatedDurationMinutes {
    if (proposedStartAt == null || proposedEndAt == null) return null;
    if (proposedEndAt!.isBefore(proposedStartAt!) ||
        proposedEndAt!.isAtSameMomentAs(proposedStartAt!)) return null;
    return proposedEndAt!.difference(proposedStartAt!).inMinutes;
  }

  static String _calculateDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) return 'Inválido';

    final diff = end.difference(start);
    final totalMinutes = diff.inMinutes;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days dia${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}min');

    return parts.isEmpty ? '—' : parts.join(' ');
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Selecionar data e hora';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  às  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateTime(
    BuildContext context, {
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final initial = isStart
        ? (proposedStartAt ?? now)
        : (proposedEndAt ??
            proposedStartAt?.add(const Duration(hours: 2)) ??
            now);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (isStart) {
      onStartAtChanged(combined);
      if (proposedEndAt != null && proposedEndAt!.isBefore(combined)) {
        onEndAtChanged(combined.add(const Duration(hours: 2)));
      }
    } else {
      if (proposedStartAt != null && combined.isBefore(proposedStartAt!)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('O fim deve ser depois do início.'),
            ),
          );
        }
        return;
      }
      onEndAtChanged(combined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration(proposedStartAt, proposedEndAt);
    final isClientFixed = !hasFlexibleSchedule &&
        (clientScheduledDate != null ||
            (clientStartTime != null && clientEndTime != null));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agendamento',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kRoxo,
            ),
          ),
          const SizedBox(height: 10),
          if (isClientFixed) ...[
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text: '📅 Cliente solicitou: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _kRoxo,
                    ),
                  ),
                  TextSpan(
                    text: clientScheduledDate != null
                        ? '${clientScheduledDate!.day.toString().padLeft(2, '0')}/${clientScheduledDate!.month.toString().padLeft(2, '0')}/${clientScheduledDate!.year} das ${clientStartTime ?? '--:--'} às ${clientEndTime ?? '--:--'}'
                        : '${clientStartTime ?? '--:--'} às ${clientEndTime ?? '--:--'}',
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              '📅 Cliente não especificou data — defina abaixo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kRoxo,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _DateTimeField(
            label: 'Início',
            icon: Icons.play_circle_outline,
            value: proposedStartAt,
            onTap: isClientFixed && clientScheduledDate != null
                ? null
                : () => _pickDateTime(context, isStart: true),
          ),
          const SizedBox(height: 10),
          _DateTimeField(
            label: 'Fim',
            icon: Icons.stop_circle_outlined,
            value: proposedEndAt,
            onTap: isClientFixed && clientStartTime != null
                ? null
                : () => _pickDateTime(context, isStart: false),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: _kRoxo),
                const SizedBox(width: 8),
                const Text(
                  'Duração estimada: ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kRoxo,
                  ),
                ),
                Text(
                  duration,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kRoxo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formatted = ProviderQuoteScheduleSection._formatDateTime(value);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _kRoxo),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kRoxo,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null ? Colors.black87 : Colors.grey,
                      fontWeight:
                          value != null ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
