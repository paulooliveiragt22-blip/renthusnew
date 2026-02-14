import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/features/jobs/domain/models/provider_my_jobs_model.dart';

class ProviderMyJobsPage extends ConsumerStatefulWidget {
  const ProviderMyJobsPage({super.key});

  @override
  ConsumerState<ProviderMyJobsPage> createState() => _ProviderMyJobsPageState();
}

class _ProviderMyJobsPageState extends ConsumerState<ProviderMyJobsPage> {
  static const _filterOptions = [7, 14, 30, 60, 90];
  int _selectedDays = 30;
  ProviderSummaryFilter _selectedFilter = ProviderSummaryFilter.all;

  void _openItem(JobCardData item) {
    if (item.jobId.isEmpty) return;

    if (item.openAsDispute) {
      context.push('${AppRoutes.providerDispute}/${item.jobId}').then((_) {
        ref.invalidate(providerMyJobsProvider(_selectedDays));
      });
      return;
    }

    context.pushJobDetails(item.jobId).then((_) {
      ref.invalidate(providerMyJobsProvider(_selectedDays));
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(providerMyJobsProvider(_selectedDays));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: dataAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Erro: $e',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                data: (result) => _buildBody(result),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF3B246B),
      ),
      child: const Text(
        'Meus pedidos',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFilterRow(ProviderMyJobsResult result) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterOptions.map((days) {
          final selected = _selectedDays == days;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                '$days dias',
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFF3B246B),
              backgroundColor: Colors.white,
              side: BorderSide(
                color:
                    selected ? const Color(0xFF3B246B) : Colors.grey.shade300,
              ),
              onSelected: (value) {
                if (!value) return;
                setState(() => _selectedDays = days);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(ProviderMyJobsResult result) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (result.countDisputes > 0)
          _buildExpandedHighlightCard(
            title: 'Reclamações',
            subtitle: 'Pedidos em disputa, priorize esses',
            count: result.countDisputes,
            baseColor: const Color(0xFFFF3B30),
            filter: ProviderSummaryFilter.dispute,
            icon: Icons.report_problem_outlined,
            isFilled: true,
          ),
        if (result.countNewServices > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildExpandedHighlightCard(
              title: 'Novos serviços aprovados',
              subtitle: 'Pedidos aguardando (view v_provider_my_jobs)',
              count: result.countNewServices,
              baseColor: const Color(0xFF0DAA00),
              filter: ProviderSummaryFilter.newApproved,
              icon: Icons.fiber_new,
              isFilled: false,
            ),
          ),
        if (result.countDisputes > 0 || result.countNewServices > 0)
          const SizedBox(height: 20),
        _buildChipsRow(result),
        const SizedBox(height: 20),
        _buildFilterRow(result),
        const SizedBox(height: 20),
        _buildJobsFromSelectedFilter(result),
      ],
    );
  }

  Widget _buildChipsRow(ProviderMyJobsResult result) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryChip(
            title: 'Aprovados',
            count: result.countNewServices,
            baseColor: const Color(0xFF0DAA00),
            filter: ProviderSummaryFilter.newApproved,
            icon: Icons.fiber_new,
          ),
          _buildSummaryChip(
            title: 'Em andamento',
            count: result.countInProgress,
            baseColor: const Color(0xFFFF6600),
            filter: ProviderSummaryFilter.inProgress,
            icon: Icons.directions_run,
          ),
          _buildSummaryChip(
            title: 'Realizados',
            count: result.countCompleted,
            baseColor: const Color(0xFF3B246B),
            filter: ProviderSummaryFilter.completed,
            icon: Icons.check_circle_outline,
          ),
          _buildSummaryChip(
            title: 'Cancelados',
            count: result.countCancelled,
            baseColor: Colors.grey.shade700,
            filter: ProviderSummaryFilter.cancelled,
            icon: Icons.cancel_outlined,
          ),
          _buildSummaryChip(
            title: 'Reclamações',
            count: result.countDisputes,
            baseColor: const Color(0xFFFF3B30),
            filter: ProviderSummaryFilter.dispute,
            icon: Icons.report_problem_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required String title,
    required int count,
    required Color baseColor,
    required ProviderSummaryFilter filter,
    required IconData icon,
  }) {
    final selected = _selectedFilter == filter;
    final hasItems = count > 0;
    final effectiveColor = hasItems ? baseColor : Colors.grey.shade400;
    final disabled = !hasItems;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                setState(() {
                  _selectedFilter =
                      (_selectedFilter == filter)
                          ? ProviderSummaryFilter.all
                          : filter;
                });
              },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? effectiveColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: effectiveColor.withOpacity(selected ? 1 : 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : effectiveColor,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.15)
                      : effectiveColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : effectiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedHighlightCard({
    required String title,
    required String subtitle,
    required int count,
    required Color baseColor,
    required ProviderSummaryFilter filter,
    required IconData icon,
    required bool isFilled,
  }) {
    final selected = _selectedFilter == filter;
    final bg = isFilled ? baseColor : Colors.white;
    final titleColor = isFilled ? Colors.white : const Color(0xFF3B246B);
    final subtitleColor =
        isFilled ? Colors.white70 : Colors.grey.shade700;
    final badgeBg =
        isFilled
            ? Colors.white.withOpacity(0.15)
            : baseColor.withOpacity(0.08);
    final badgeText = isFilled ? Colors.white : baseColor;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter =
              (_selectedFilter == filter)
                  ? ProviderSummaryFilter.all
                  : filter;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? baseColor : Colors.transparent,
            width: selected ? 1.5 : 0.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.16),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? Colors.white.withOpacity(0.12)
                    : baseColor.withOpacity(0.12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isFilled ? Colors.white : baseColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Toque para ver',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isFilled ? Colors.white : baseColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: badgeText,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  selected
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: isFilled ? Colors.white : baseColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsFromSelectedFilter(ProviderMyJobsResult result) {
    List<JobCardData> selectedItems = [];
    String title = '';

    switch (_selectedFilter) {
      case ProviderSummaryFilter.all:
        return const SizedBox.shrink();
      case ProviderSummaryFilter.newApproved:
        selectedItems = result.newServicesItems;
        title = 'Novos serviços';
        break;
      case ProviderSummaryFilter.inProgress:
        selectedItems = result.inProgressItems;
        title = 'Serviços em andamento';
        break;
      case ProviderSummaryFilter.completed:
        selectedItems = result.completedItems;
        title = 'Serviços realizados';
        break;
      case ProviderSummaryFilter.dispute:
        selectedItems = result.disputeItems;
        title = 'Reclamações / Disputas';
        break;
      case ProviderSummaryFilter.cancelled:
        selectedItems = result.cancelledItems;
        title = 'Pedidos cancelados';
        break;
    }

    if (selectedItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3B246B),
          ),
        ),
        const SizedBox(height: 8),
        ...selectedItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildJobCard(item),
          );
        }),
      ],
    );
  }

  Widget _buildJobCard(JobCardData item) {
    final hasUnread = item.unreadMessages > 0;
    final unreadText = item.unreadMessages == 1
        ? '1 nova mensagem'
        : '${item.unreadMessages} novas mensagens';

    return InkWell(
      onTap: () => _openItem(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Pedido: ${item.jobCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (item.priceLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    size: 16,
                    color: Color(0xFF3B246B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.priceLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                ],
              ),
            ],
            if (item.dateLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.dateLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.mark_chat_unread,
                    size: 14,
                    color: Color(0xFF3B246B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unreadText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF3B246B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                item.openAsDispute ? 'Ver reclamação' : 'Ver detalhes',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF3B246B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
