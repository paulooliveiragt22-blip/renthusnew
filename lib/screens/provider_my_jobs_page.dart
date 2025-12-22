import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'job_details_page.dart';
import 'provider_dispute_page.dart'; // ✅ IMPORT DA TELA DE DISPUTA

class ProviderMyJobsPage extends StatefulWidget {
  const ProviderMyJobsPage({super.key});

  @override
  State<ProviderMyJobsPage> createState() => _ProviderMyJobsPageState();
}

class _ProviderMyJobsPageState extends State<ProviderMyJobsPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  // filtro de período em dias
  final List<int> _filterOptions = [7, 14, 30, 60, 90];
  int _selectedDays = 30;

  /// Lista completa (jobs + disputas)
  List<_JobCardData> _allItems = [];

  /// job_id -> qtd mensagens não lidas
  Map<String, int> _unreadMessagesByJobId = {};

  /// Grupos (jobs)
  List<_JobCardData> _newServicesItems = []; // waitingClient
  List<_JobCardData> _inProgressItems = [];
  List<_JobCardData> _completedItems = [];
  List<_JobCardData> _disputeItems = []; // ✅ agora preenchido pela view
  List<_JobCardData> _cancelledItems = [];

  /// Contadores
  int _countNewServices = 0;
  int _countInProgress = 0;
  int _countCompleted = 0;
  int _countDisputes = 0;
  int _countCancelled = 0;

  /// Chip selecionado
  _SummaryFilter _selectedFilter = _SummaryFilter.all;

  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  DateTime _sinceUtc() {
    return DateTime.now().toUtc().subtract(Duration(days: _selectedDays));
  }

  Future<void> _loadJobs() async {
    setState(() {
      isLoading = true;
      _allItems = [];
      _unreadMessagesByJobId = {};
      _selectedFilter = _SummaryFilter.all;

      _newServicesItems = [];
      _inProgressItems = [];
      _completedItems = [];
      _disputeItems = [];
      _cancelledItems = [];

      _countNewServices = 0;
      _countInProgress = 0;
      _countCompleted = 0;
      _countDisputes = 0;
      _countCancelled = 0;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final since = _sinceUtc().toIso8601String();

      // 1) Mensagens não lidas (chat)
      final notifRes = await supabase
          .from('notifications')
          .select('data')
          .eq('user_id', user.id)
          .eq('channel', 'app')
          .eq('read', false)
          .contains('data', {'type': 'chat_message'});

      final Map<String, int> unreadByJobId = {};
      for (final row in notifRes as List<dynamic>) {
        final data = row['data'];
        if (data is Map) {
          final jobId = data['job_id']?.toString();
          if (jobId != null) {
            unreadByJobId[jobId] = (unreadByJobId[jobId] ?? 0) + 1;
          }
        }
      }

      // 2) Jobs do prestador (VIEW v_provider_my_jobs)
      // OBS: se sua view não tiver created_at, remova o .gte(...)
      final jobsRes = await supabase
          .from('v_provider_my_jobs')
          .select('*')
          .gte('created_at', since)
          .order('created_at', ascending: false);

      final List<_JobCardData> jobCards = [];

      for (final j in jobsRes as List<dynamic>) {
        final jobId = j['job_id']?.toString() ?? '';
        if (jobId.isEmpty) continue;

        final rawStatus = j['status']?.toString() ?? '';
        final uiGroup = j['ui_group']?.toString() ?? 'waitingClient';

        final createdAt = DateTime.tryParse(
              (j['candidate_created_at'] ?? j['created_at']).toString(),
            )?.toLocal() ??
            DateTime.now();

        final statusLabel = _mapStatusLabel(rawStatus);
        final statusColor = _mapStatusColor(rawStatus);

        final amountProvider = j['amount_provider'];
        final priceLabel = amountProvider != null
            ? _currencyFormatter.format((amountProvider as num).toDouble())
            : '';

        jobCards.add(
          _JobCardData(
            jobId: jobId,
            jobCode: j['job_code']?.toString() ?? 'Serviço',
            description: j['description']?.toString() ?? '',
            priceLabel: priceLabel,
            rawStatus: rawStatus,
            statusLabel: statusLabel,
            statusColor: statusColor,
            dateLabel: DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
            sortDate: createdAt,
            unreadMessages: unreadByJobId[jobId] ?? 0,
            group: uiGroup == 'active'
                ? _JobGroup.active
                : uiGroup == 'history'
                    ? _JobGroup.history
                    : _JobGroup.waitingClient,
            // job normal abre JobDetails
            openAsDispute: false,
          ),
        );
      }

      // 3) Disputas do prestador (VIEW v_provider_disputes) ✅ SEM tabela disputes crua
      final disputesRes = await supabase
          .from('v_provider_disputes')
          .select('''
            dispute_id,
            job_id,
            dispute_status,
            dispute_description,
            dispute_created_at
          ''')
          .gte('dispute_created_at', since)
          .order('dispute_created_at', ascending: false);

      final List<_JobCardData> disputeCards = [];

      for (final d in disputesRes as List<dynamic>) {
        final jobId = d['job_id']?.toString() ?? '';
        if (jobId.isEmpty) continue;

        final createdAt = DateTime.tryParse(
              d['dispute_created_at']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();

        disputeCards.add(
          _JobCardData(
            jobId: jobId,
            jobCode: 'Disputa • ${_shortId(jobId)}',
            description: d['dispute_description']?.toString() ?? '',
            priceLabel: '',
            rawStatus: 'dispute',
            statusLabel: 'Em disputa',
            statusColor: const Color(0xFFFF3B30),
            dateLabel: DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
            sortDate: createdAt,
            unreadMessages: unreadByJobId[jobId] ?? 0,
            group: _JobGroup.active,
            // disputa abre ProviderDisputePage
            openAsDispute: true,
          ),
        );
      }

      // 4) Consolida tudo
      final List<_JobCardData> all = [...jobCards, ...disputeCards];

      // 5) Categoriza
      final cancelled = all.where((e) {
        final s = e.rawStatus;
        return s == 'cancelled' ||
            s == 'cancelled_by_client' ||
            s == 'cancelled_by_provider';
      }).toList();

      final disputes = all.where((e) => e.openAsDispute).toList();

      final waitingClient =
          all.where((e) => e.group == _JobGroup.waitingClient).toList();

      final active = all.where((e) => e.group == _JobGroup.active).toList();

      final history = all.where((e) => e.group == _JobGroup.history).toList();

      setState(() {
        _unreadMessagesByJobId = unreadByJobId;

        _allItems = all;

        _disputeItems = disputes;
        _cancelledItems = cancelled;

        _newServicesItems = waitingClient;
        _inProgressItems = active;
        _completedItems = history;

        _countDisputes = _disputeItems.length;
        _countCancelled = _cancelledItems.length;

        _countNewServices = _newServicesItems.length;
        _countInProgress = _inProgressItems.length;
        _countCompleted = _completedItems.length;

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ProviderMyJobs: $e');
      setState(() => isLoading = false);
    }
  }

  String _mapStatusLabel(String status) {
    switch (status) {
      case 'waiting_providers':
      case 'open':
        return 'Disponível';
      case 'accepted':
        return 'Aguardando início';
      case 'on_the_way':
        return 'A caminho';
      case 'in_progress':
        return 'Em execução';
      case 'execution_overdue':
        return 'Fora do prazo';
      case 'completed':
        return 'Finalizado';
      case 'dispute':
      case 'dispute_open':
        return 'Em disputa';
      case 'refunded':
        return 'Estornado';
      case 'cancelled':
        return 'Cancelado';
      case 'cancelled_by_client':
        return 'Cancelado pelo cliente';
      case 'cancelled_by_provider':
        return 'Cancelado por você';
      default:
        return status.isEmpty ? 'Indefinido' : status;
    }
  }

  Color _mapStatusColor(String status) {
    switch (status) {
      case 'waiting_providers':
      case 'open':
        return Colors.blueGrey;
      case 'accepted':
      case 'on_the_way':
      case 'in_progress':
        return const Color(0xFF34A853);
      case 'execution_overdue':
        return Colors.red;
      case 'completed':
        return const Color(0xFF3B246B);
      case 'dispute':
      case 'dispute_open':
        return const Color(0xFFFF3B30);
      case 'refunded':
        return const Color(0xFF0DAA00);
      case 'cancelled':
      case 'cancelled_by_client':
      case 'cancelled_by_provider':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade700;
    }
  }

  void _openItem(_JobCardData item) {
    if (item.jobId.isEmpty) return;

    if (item.openAsDispute) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderDisputePage(jobId: item.jobId),
        ),
      ).then((_) => _loadJobs());
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(jobId: item.jobId),
      ),
    ).then((_) => _loadJobs());
  }

  // ----------------- BUILD -----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
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

  Widget _buildFilterRow() {
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
                _loadJobs();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (_countDisputes > 0)
          _buildExpandedHighlightCard(
            title: 'Reclamações',
            subtitle: 'Pedidos em disputa, priorize esses',
            count: _countDisputes,
            baseColor: const Color(0xFFFF3B30),
            filter: _SummaryFilter.dispute,
            icon: Icons.report_problem_outlined,
            isFilled: true,
          ),
        if (_countNewServices > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildExpandedHighlightCard(
              title: 'Novos serviços aprovados',
              subtitle: 'Pedidos aguardando (view v_provider_my_jobs)',
              count: _countNewServices,
              baseColor: const Color(0xFF0DAA00),
              filter: _SummaryFilter.newApproved,
              icon: Icons.fiber_new,
              isFilled: false,
            ),
          ),
        if (_countDisputes > 0 || _countNewServices > 0)
          const SizedBox(height: 20),
        _buildChipsRow(),
        const SizedBox(height: 20),
        _buildFilterRow(),
        const SizedBox(height: 20),
        _buildJobsFromSelectedFilter(),
      ],
    );
  }

  Widget _buildChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryChip(
            title: 'Aprovados',
            count: _countNewServices,
            baseColor: const Color(0xFF0DAA00),
            filter: _SummaryFilter.newApproved,
            icon: Icons.fiber_new,
          ),
          _buildSummaryChip(
            title: 'Em andamento',
            count: _countInProgress,
            baseColor: const Color(0xFFFF6600),
            filter: _SummaryFilter.inProgress,
            icon: Icons.directions_run,
          ),
          _buildSummaryChip(
            title: 'Realizados',
            count: _countCompleted,
            baseColor: const Color(0xFF3B246B),
            filter: _SummaryFilter.completed,
            icon: Icons.check_circle_outline,
          ),
          _buildSummaryChip(
            title: 'Cancelados',
            count: _countCancelled,
            baseColor: Colors.grey.shade700,
            filter: _SummaryFilter.cancelled,
            icon: Icons.cancel_outlined,
          ),
          _buildSummaryChip(
            title: 'Reclamações',
            count: _countDisputes,
            baseColor: const Color(0xFFFF3B30),
            filter: _SummaryFilter.dispute,
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
    required _SummaryFilter filter,
    required IconData icon,
  }) {
    final bool selected = _selectedFilter == filter;
    final bool hasItems = count > 0;

    final Color effectiveColor = hasItems ? baseColor : Colors.grey.shade400;
    final bool disabled = !hasItems;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                setState(() {
                  _selectedFilter =
                      (_selectedFilter == filter) ? _SummaryFilter.all : filter;
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    required _SummaryFilter filter,
    required IconData icon,
    required bool isFilled,
  }) {
    final bool selected = _selectedFilter == filter;

    final Color bg = isFilled ? baseColor : Colors.white;
    final Color titleColor = isFilled ? Colors.white : const Color(0xFF3B246B);
    final Color subtitleColor =
        isFilled ? Colors.white70 : Colors.grey.shade700;
    final Color badgeBg =
        isFilled ? Colors.white.withOpacity(0.15) : baseColor.withOpacity(0.08);
    final Color badgeText = isFilled ? Colors.white : baseColor;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter =
              (_selectedFilter == filter) ? _SummaryFilter.all : filter;
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

  Widget _buildJobsFromSelectedFilter() {
    List<_JobCardData> selectedItems = [];
    String title = '';

    switch (_selectedFilter) {
      case _SummaryFilter.all:
        return const SizedBox.shrink();
      case _SummaryFilter.newApproved:
        selectedItems = _newServicesItems;
        title = 'Novos serviços';
        break;
      case _SummaryFilter.inProgress:
        selectedItems = _inProgressItems;
        title = 'Serviços em andamento';
        break;
      case _SummaryFilter.completed:
        selectedItems = _completedItems;
        title = 'Serviços realizados';
        break;
      case _SummaryFilter.dispute:
        selectedItems = _disputeItems;
        title = 'Reclamações / Disputas';
        break;
      case _SummaryFilter.cancelled:
        selectedItems = _cancelledItems;
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
        }).toList(),
      ],
    );
  }

  Widget _buildJobCard(_JobCardData item) {
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

enum _SummaryFilter {
  all,
  newApproved,
  inProgress,
  completed,
  dispute,
  cancelled,
}

enum _JobGroup {
  active,
  waitingClient,
  history,
}

class _JobCardData {
  final String jobId;
  final String jobCode;
  final String description;
  final String priceLabel;
  final String rawStatus;
  final String statusLabel;
  final Color statusColor;
  final String dateLabel;
  final DateTime sortDate;
  final int unreadMessages;
  final _JobGroup group;

  /// ✅ se true, abre ProviderDisputePage
  final bool openAsDispute;

  _JobCardData({
    required this.jobId,
    required this.jobCode,
    required this.description,
    required this.priceLabel,
    required this.rawStatus,
    required this.statusLabel,
    required this.statusColor,
    required this.dateLabel,
    required this.sortDate,
    required this.group,
    this.unreadMessages = 0,
    required this.openAsDispute,
  });
}
