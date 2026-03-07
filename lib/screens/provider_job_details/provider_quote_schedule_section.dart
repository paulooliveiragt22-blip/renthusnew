import 'package:flutter/cupertino.dart';
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
        proposedEndAt!.isAtSameMomentAs(proposedStartAt!)) {
      return null;
    }
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

  /// [fixedDate] = data já definida pelo cliente; pula o date picker e abre
  /// só o seletor de hora.
  Future<void> _pickDateTime(
    BuildContext context, {
    required bool isStart,
    DateTime? fixedDate,
  }) async {
    final now = DateTime.now();
    final initial = isStart
        ? (proposedStartAt ?? fixedDate ?? now)
        : (proposedEndAt ??
            proposedStartAt?.add(const Duration(hours: 2)) ??
            now);

    final DateTime date;
    if (fixedDate != null) {
      // Data bloqueada pelo cliente — só escolhe a hora
      date = fixedDate;
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        locale: const Locale('pt', 'BR'),
      );
      if (picked == null || !context.mounted) return;
      date = picked;
    }

    final time = await _showScrollTimePicker(
      context,
      initial: TimeOfDay.fromDateTime(initial),
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
            const SnackBar(content: Text('O fim deve ser depois do início.')),
          );
        }
        return;
      }
      onEndAtChanged(combined);
    }
  }

  static Future<TimeOfDay?> _showScrollTimePicker(
    BuildContext context, {
    required TimeOfDay initial,
  }) async {
    int selectedHour = initial.hour;
    int selectedMinute = initial.minute;

    final hourController =
        FixedExtentScrollController(initialItem: initial.hour);
    final minuteController =
        FixedExtentScrollController(initialItem: initial.minute);

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  const Text(
                    'Selecionar horário',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      ctx,
                      TimeOfDay(
                          hour: selectedHour, minute: selectedMinute),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                          color: _kRoxo, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: hourController,
                      itemExtent: 48,
                      onSelectedItemChanged: (i) => selectedHour = i,
                      children: List.generate(
                        24,
                        (i) => Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(':',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: minuteController,
                      itemExtent: 48,
                      onSelectedItemChanged: (i) => selectedMinute = i,
                      children: List.generate(
                        60,
                        (i) => Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    hourController.dispose();
    minuteController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration(proposedStartAt, proposedEndAt);

    // Cliente tem data definida?
    final clientHasDate =
        !hasFlexibleSchedule && clientScheduledDate != null;
    // Cliente tem hora de início definida?
    final clientHasStartTime = clientStartTime != null;

    // Início: bloqueado somente quando cliente definiu data E hora de início.
    // Quando só definiu a data (sem hora), prestador escolhe apenas a hora.
    final VoidCallback? startOnTap;
    if (clientHasDate && clientHasStartTime) {
      startOnTap = null; // completamente bloqueado
    } else if (clientHasDate) {
      // Data fixa, hora livre → abre só o seletor de hora
      startOnTap =
          () => _pickDateTime(context, isStart: true, fixedDate: clientScheduledDate);
    } else {
      startOnTap = () => _pickDateTime(context, isStart: true);
    }

    // Fim: sempre editável pelo prestador (inlined no widget abaixo)

    // Texto informativo sobre o pedido do cliente
    final bool showClientInfo =
        !hasFlexibleSchedule && (clientScheduledDate != null || clientHasStartTime);

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
          if (showClientInfo) ...[
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
                        ? '${clientScheduledDate!.day.toString().padLeft(2, '0')}/${clientScheduledDate!.month.toString().padLeft(2, '0')}/${clientScheduledDate!.year}'
                            '${clientStartTime != null ? ' às $clientStartTime' : ' (horário a definir)'}'
                        : '${clientStartTime ?? '--:--'} às ${clientEndTime ?? '--:--'}',
                  ),
                ],
              ),
            ),
            if (clientHasDate && !clientHasStartTime)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Selecione o horário de início e fim da sua proposta.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
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
            onTap: startOnTap,
          ),
          const SizedBox(height: 10),
          _DateTimeField(
            label: 'Fim',
            icon: Icons.stop_circle_outlined,
            value: proposedEndAt,
            onTap: () => _pickDateTime(context, isStart: false),
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
