import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kRoxo = Color(0xFF3B246B);
const _kGreen = Color(0xFF0DAA00);

class JobStatusTimeline extends StatelessWidget {
  const JobStatusTimeline({
    super.key,
    required this.job,
    required this.candidates,
    required this.hasPaid,
  });

  final Map<String, dynamic> job;
  final List<Map<String, dynamic>> candidates;
  final bool hasPaid;

  @override
  Widget build(BuildContext context) {
    final status = (job['status'] as String?) ?? '';
    final steps = _buildSteps(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acompanhamento',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kRoxo,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            return _StepRow(
              step: step,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  List<_TimelineStep> _buildSteps(String status) {
    final createdAt = _fmtDate(job['created_at']);
    final hasProposals = candidates.isNotEmpty;
    final isChosen = const [
      'accepted',
      'on_the_way',
      'in_progress',
      'completed',
    ].contains(status);
    final isInProgress = status == 'in_progress';
    final isCompleted = status == 'completed';

    String? approvedProviderName;
    if (isChosen) {
      final providerId = job['provider_id']?.toString();
      if (providerId != null) {
        for (final c in candidates) {
          if (c['provider_id']?.toString() == providerId) {
            approvedProviderName =
                (c['provider_name'] as String?) ?? 'Profissional';
            break;
          }
        }
      }
      approvedProviderName ??= 'Profissional confirmado';
    }

    final paymentAmount = (job['amount_total'] as num?)?.toDouble() ??
        (candidates
            .where((c) =>
                c['provider_id']?.toString() == job['provider_id']?.toString())
            .map((c) => (c['approximate_price'] as num?)?.toDouble())
            .firstWhere((v) => v != null, orElse: () => null));

    final scheduledDate = _fmtDateOnly(job['scheduled_date']) ??
        _fmtDateOnly(job['scheduled_at']);

    // Determine which step is "current" (first non-done step)
    final doneFlags = [
      true, // Pedido criado — always done
      hasProposals,
      isChosen,
      hasPaid,
      isInProgress || isCompleted,
      isCompleted,
    ];

    int currentIndex = doneFlags.indexWhere((d) => !d);
    if (currentIndex == -1) currentIndex = doneFlags.length; // all done

    _StepState stateFor(int i) {
      if (doneFlags[i]) return _StepState.done;
      if (i == currentIndex) return _StepState.current;
      return _StepState.future;
    }

    return [
      _TimelineStep(
        title: 'Pedido criado',
        subtitle: createdAt.isNotEmpty ? createdAt : null,
        state: stateFor(0),
      ),
      _TimelineStep(
        title: 'Propostas recebidas',
        subtitle: hasProposals
            ? '${candidates.length} proposta${candidates.length > 1 ? 's' : ''}'
            : 'Aguardando profissionais...',
        state: stateFor(1),
      ),
      _TimelineStep(
        title: 'Profissional escolhido',
        subtitle: isChosen ? approvedProviderName : 'Escolha uma proposta',
        state: stateFor(2),
      ),
      _TimelineStep(
        title: 'Pagamento confirmado',
        subtitle: hasPaid && paymentAmount != null
            ? 'Valor: ${_currencyBr.format(paymentAmount)}'
            : (hasPaid ? 'Confirmado' : 'Pendente'),
        state: stateFor(3),
      ),
      _TimelineStep(
        title: 'Serviço em andamento',
        subtitle: (isInProgress || isCompleted)
            ? (scheduledDate ?? 'Em execução')
            : null,
        state: stateFor(4),
      ),
      _TimelineStep(
        title: 'Concluído',
        subtitle: isCompleted ? 'Avalie o profissional!' : null,
        state: stateFor(5),
      ),
    ];
  }

  static final _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  static String _fmtDate(dynamic iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  static String? _fmtDateOnly(dynamic iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return null;
    }
  }
}

enum _StepState { done, current, future }

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    this.subtitle,
    required this.state,
  });

  final String title;
  final String? subtitle;
  final _StepState state;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final _TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicator column
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _indicator(),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.state == _StepState.done
                          ? _kGreen
                          : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: step.state == _StepState.future
                          ? Colors.grey.shade400
                          : Colors.black87,
                    ),
                  ),
                  if (step.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: step.state == _StepState.done
                            ? Colors.black54
                            : step.state == _StepState.current
                                ? _kRoxo
                                : Colors.grey.shade400,
                        fontWeight: step.state == _StepState.current
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicator() {
    switch (step.state) {
      case _StepState.done:
        return const CircleAvatar(
          radius: 14,
          backgroundColor: _kGreen,
          child: Icon(Icons.check, color: Colors.white, size: 16),
        );
      case _StepState.current:
        return const _PulsingIndicator();
      case _StepState.future:
        return CircleAvatar(
          radius: 14,
          backgroundColor: Colors.grey.shade200,
          child: null,
        );
    }
  }
}

class _PulsingIndicator extends StatefulWidget {
  const _PulsingIndicator();

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const CircleAvatar(
        radius: 14,
        backgroundColor: _kRoxo,
        child: Icon(Icons.more_horiz, color: Colors.white, size: 16),
      ),
    );
  }
}
