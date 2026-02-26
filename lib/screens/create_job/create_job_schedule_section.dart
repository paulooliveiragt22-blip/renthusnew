import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);
const kLaranja = Color(0xFFFF6600);

class CreateJobScheduleSection extends StatelessWidget {
  const CreateJobScheduleSection({
    super.key,
    required this.hasFlexibleSchedule,
    required this.scheduledDate,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.hasPreferredTime,
    required this.onToggleFlexible,
    required this.onTogglePreferredTime,
    required this.onDateSelected,
    required this.onStartTimeSelected,
    required this.onEndTimeSelected,
  });

  final bool hasFlexibleSchedule;
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledStartTime;
  final TimeOfDay? scheduledEndTime;
  final bool hasPreferredTime;
  final ValueChanged<bool> onToggleFlexible;
  final ValueChanged<bool> onTogglePreferredTime;
  final ValueChanged<DateTime?> onDateSelected;
  final ValueChanged<TimeOfDay?> onStartTimeSelected;
  final ValueChanged<TimeOfDay?> onEndTimeSelected;

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: scheduledDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) onDateSelected(picked);
  }

  Future<void> _pickStartTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: scheduledStartTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) onStartTimeSelected(picked);
  }

  Future<void> _pickEndTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: scheduledEndTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) onEndTimeSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data e horário',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kRoxo,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text(
            'Tenho preferência de data/horário',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          value: !hasFlexibleSchedule,
          activeColor: kRoxo,
          onChanged: (v) => onToggleFlexible(!v),
          contentPadding: EdgeInsets.zero,
        ),
        if (!hasFlexibleSchedule) ...[
          const SizedBox(height: 12),
          _ScheduleField(
            label: 'Data',
            value: scheduledDate != null
                ? _formatDate(scheduledDate!)
                : 'Selecionar data',
            onTap: () => _pickDate(context),
          ),
          if (scheduledDate != null) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text(
                'Quero informar horário',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              value: hasPreferredTime,
              activeColor: kRoxo,
              onChanged: onTogglePreferredTime,
              contentPadding: EdgeInsets.zero,
            ),
            if (hasPreferredTime) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ScheduleField(
                      label: 'Início',
                      value: scheduledStartTime != null
                          ? _formatTime(scheduledStartTime!)
                          : 'Selecionar início',
                      onTap: () => _pickStartTime(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ScheduleField(
                      label: 'Fim',
                      value: scheduledEndTime != null
                          ? _formatTime(scheduledEndTime!)
                          : 'Selecionar fim',
                      onTap: () => _pickEndTime(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ] else ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'O prestador vai sugerir data e horário na proposta.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kRoxo,
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
      ),
    );
  }
}
