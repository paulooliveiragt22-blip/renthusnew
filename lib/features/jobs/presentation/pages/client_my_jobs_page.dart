import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/shared_preferences_provider.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/features/jobs/domain/models/client_my_jobs_model.dart';
import 'package:renthus/features/jobs/presentation/pages/client_job_details_page.dart';

class ClientMyJobsPage extends ConsumerStatefulWidget {
  const ClientMyJobsPage({super.key});

  @override
  ConsumerState<ClientMyJobsPage> createState() => _ClientMyJobsPageState();
}

class _ClientMyJobsPageState extends ConsumerState<ClientMyJobsPage> {
  int _selectedStatusFilter = 0;
  static const _filterOptions = [7, 14, 30, 60, 90];
  int _selectedDays = 7;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _markCandidatesSeen(Map<String, dynamic> job) async {
    final jobId = job['id']?.toString();
    if (jobId == null || jobId.isEmpty) return;

    final total = (job['candidates_total'] as int?) ?? 0;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('client_seen_candidates_$jobId', total);
  }

  void _openJobDetails(Map<String, dynamic> job) {
    _markCandidatesSeen(job);

    final id = job['id']?.toString();
    if (id == null || id.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientJobDetailsPage(jobId: id),
      ),
    ).then((_) {
      ref.invalidate(clientMyJobsProvider(_selectedDays));
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return _dateFormat.format(dt);
    } catch (_) {
      return iso;
    }
  }

  List<Map<String, dynamic>> _applySearch(
      List<Map<String, dynamic>> jobs, String term) {
    if (term.isEmpty) return jobs;
    return jobs.where((job) {
      final title = (job['title'] as String? ?? '').toLowerCase();
      final desc = (job['description'] as String? ?? '').toLowerCase();
      return title.contains(term) || desc.contains(term);
    }).toList();
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'open':
      case 'waiting_providers':
        return 'Aguardando profissionais';
      case 'accepted':
        return 'Aguardando início';
      case 'on_the_way':
        return 'Profissional a caminho';
      case 'in_progress':
        return 'Em andamento';
      case 'execution_overdue':
        return 'Fora do prazo de execução';
      case 'completed':
        return 'Finalizado';
      case 'cancelled_by_client':
        return 'Cancelado pelo cliente';
      case 'cancelled_by_provider':
        return 'Cancelado pelo profissional';
      case 'refunded':
        return 'Estornado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status.isEmpty ? 'Em andamento' : status;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'open':
      case 'waiting_providers':
        return Colors.blueGrey;
      case 'accepted':
        return const Color(0xFFFF6600);
      case 'on_the_way':
        return Colors.blue;
      case 'in_progress':
        return const Color(0xFF0DAA00);
      case 'execution_overdue':
        return Colors.red;
      case 'completed':
        return const Color(0xFF3B246B);
      case 'cancelled':
      case 'cancelled_by_client':
      case 'cancelled_by_provider':
        return Colors.grey;
      case 'refunded':
        return const Color(0xFF0DAA00);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _itemsForSelectedGroup(ClientMyJobsResult result) {
    switch (_selectedStatusFilter) {
      case 0:
        return result.requestedItems;
      case 1:
        return result.inProgressItems;
      case 2:
        return result.completedItems;
      case 3:
        return result.cancelledItems;
      case 4:
        return result.disputeItems;
      default:
        return result.requestedItems;
    }
  }

  List<Map<String, dynamic>> _jobsWithOpenDisputes(
          ClientMyJobsResult result) =>
      result.disputeItems
          .where((job) =>
              ((job['dispute_status'] as String?) ?? '') == 'open')
          .toList();

  List<Map<String, dynamic>> _jobsWithNewQuotes(ClientMyJobsResult result) =>
      result.requestedItems.where((job) {
        final status = (job['status'] as String?) ?? '';
        final quotesCount = (job['quotes_count'] as int?) ?? 0;
        return (status == 'open' || status == 'waiting_providers') &&
            quotesCount > 0;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(clientMyJobsProvider(_selectedDays));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: dataAsync.when(
                loading: () => _buildLoadingSkeleton(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (result) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(clientMyJobsProvider(_selectedDays));
                  },
                  child: _buildDashboard(result),
                ),
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
      decoration: const BoxDecoration(color: Color(0xFF3B246B)),
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

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 0.8),
          ),
        );
      },
    );
  }

  Widget _buildDashboard(ClientMyJobsResult result) {
    final total = result.countRequested +
        result.countInProgress +
        result.countCompleted +
        result.countCancelled +
        result.countDisputes;

    if (total == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'Você ainda não tem pedidos.\nQuando solicitar serviços, eles aparecerão aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      );
    }

    final hasDisputes = _jobsWithOpenDisputes(result).isNotEmpty;
    final hasQuotes = _jobsWithNewQuotes(result).isNotEmpty;
    final baseJobs = _itemsForSelectedGroup(result);
    final visibleJobs = _applySearch(baseJobs, _searchTerm);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (hasDisputes) _buildDisputeCard(result),
        if (hasDisputes && hasQuotes) const SizedBox(height: 12),
        if (hasQuotes) _buildNewQuotesCard(result),
        if (hasDisputes || hasQuotes) const SizedBox(height: 20),
        _buildSearchField(),
        const SizedBox(height: 12),
        _buildStatusFilterRow(result),
        const SizedBox(height: 12),
        _buildDaysFilterRow(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${baseJobs.length} pedidos • últimos $_selectedDays dias',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
        if (visibleJobs.isEmpty)
          const Text(
            'Nenhum pedido para esse filtro.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          )
        else
          ...visibleJobs.map((j) => _buildJobCard(j)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() => _searchTerm = value.trim().toLowerCase());
      },
      decoration: InputDecoration(
        hintText: 'Buscar por serviço...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          borderSide: BorderSide(color: Color(0xFF3B246B), width: 1.2),
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDisputeCard(ClientMyJobsResult result) {
    final disputeJobs = _jobsWithOpenDisputes(result);
    final count = disputeJobs.length;

    const red = Color(0xFFE53935);
    if (count == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: red,
          collapsedBackgroundColor: red,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reclamações em aberto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pedidos em disputa, priorize esses.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          children: disputeJobs
              .map(
                (j) => ListTile(
                  onTap: () => _openJobDetails(j),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    (j['description'] as String?) ??
                        (j['title'] as String?) ??
                        'Serviço',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Criado em: ${_formatDate(j['created_at']?.toString())}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildNewQuotesCard(ClientMyJobsResult result) {
    final jobsWithQuotes = _jobsWithNewQuotes(result);
    final count = jobsWithQuotes.length;

    const green = Color(0xFF0DAA00);
    if (count == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          iconColor: green,
          collapsedIconColor: green,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          title: Row(
            children: [
              const Icon(Icons.new_releases_outlined, color: green),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Novos orçamentos',
                      style: TextStyle(
                        color: Color(0xFF3B246B),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pedidos com novos profissionais interessados.',
                      style: TextStyle(color: Colors.black87, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          children: jobsWithQuotes
              .map(
                (j) => ListTile(
                  onTap: () => _openJobDetails(j),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    (j['description'] as String?) ??
                        (j['title'] as String?) ??
                        'Serviço',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3B246B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Orçamentos: ${(j['quotes_count'] as int?) ?? 0}',
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStatusFilterRow(ClientMyJobsResult result) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatusFilterChip(
            label: 'Solicitados',
            count: result.countRequested,
            isSelected: _selectedStatusFilter == 0,
            color: const Color(0xFF0DAA00),
            icon: Icons.assignment_outlined,
            onTap: () => setState(() => _selectedStatusFilter = 0),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Em andamento',
            count: result.countInProgress,
            isSelected: _selectedStatusFilter == 1,
            color: const Color(0xFFFF6600),
            icon: Icons.play_arrow_rounded,
            onTap: () => setState(() => _selectedStatusFilter = 1),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Realizados',
            count: result.countCompleted,
            isSelected: _selectedStatusFilter == 2,
            color: const Color(0xFF3B246B),
            icon: Icons.check_circle_outline,
            onTap: () => setState(() => _selectedStatusFilter = 2),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Cancelados',
            count: result.countCancelled,
            isSelected: _selectedStatusFilter == 3,
            color: Colors.grey,
            icon: Icons.close_rounded,
            onTap: () => setState(() => _selectedStatusFilter = 3),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Reclamações',
            count: result.countDisputes,
            isSelected: _selectedStatusFilter == 4,
            color: const Color(0xFFE53935),
            icon: Icons.report_gmailerrorred_outlined,
            onTap: () => setState(() => _selectedStatusFilter = 4),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysFilterRow() {
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

  Widget _buildJobCard(Map<String, dynamic> j) {
    final title = (j['title'] as String?) ?? 'Serviço';
    final description = (j['description'] as String?) ?? '';
    final displayTitle = description.isNotEmpty ? description : title;
    final jobCode = (j['job_code'] as String?) ?? '';

    final status = (j['status'] as String?) ?? '';
    final createdAt = j['created_at']?.toString();

    final int quotesCount = (j['quotes_count'] as int?) ?? 0;
    final bool hasQuotes = quotesCount > 0;

    final int deltaCandidates = (j['new_candidates_count'] as int?) ?? 0;
    final int displayCandidates =
        status == 'waiting_providers' ? deltaCandidates : 0;

    final bool isOngoing = ![
      'completed',
      'cancelled_by_client',
      'cancelled_by_provider',
      'cancelled',
      'refunded',
    ].contains(status);

    String dateInfo = '';
    if (createdAt != null) dateInfo = 'Criado em: ${_formatDate(createdAt)}';

    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);

    return InkWell(
      onTap: () => _openJobDetails(j),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOngoing
                ? statusColor.withOpacity(0.35)
                : Colors.grey.shade300,
            width: 0.9,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (jobCode.isNotEmpty) ...[
              Text(
                'Pedido #$jobCode',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (status == 'waiting_providers' || status == 'open')
                  _StatusChip(hasQuotes: hasQuotes, quotesCount: quotesCount)
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            if (displayCandidates > 0) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _InfoPill(
                    icon: Icons.person_add_alt_1_outlined,
                    color: const Color(0xFF0DAA00),
                    text:
                        'Você tem $displayCandidates novo${displayCandidates == 1 ? '' : 's'} candidato${displayCandidates == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              'Orçamento',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (dateInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                dateInfo,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Ver detalhes',
                style: TextStyle(
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

class _StatusChip extends StatelessWidget {
  final bool hasQuotes;
  final int quotesCount;

  const _StatusChip({
    required this.hasQuotes,
    required this.quotesCount,
  });

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF0DAA00);
    const cinzaTexto = Color(0xFF60707E);

    final bgColor =
        hasQuotes ? const Color(0xFFE0F2E9) : const Color(0xFFE6ECF0);
    final txtColor = hasQuotes ? verde : cinzaTexto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            hasQuotes
                ? 'Você tem novos orçamentos'
                : 'Aguardando profissionais',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: txtColor,
            ),
          ),
        ),
        if (hasQuotes) ...[
          const SizedBox(height: 2),
          Text(
            'Quantidade: $quotesCount',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: verde,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? Colors.white : Colors.grey.shade50;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoPill({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
