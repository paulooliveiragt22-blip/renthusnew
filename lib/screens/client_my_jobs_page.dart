import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_job_details_page.dart';

class ClientMyJobsPage extends StatefulWidget {
  const ClientMyJobsPage({super.key});

  @override
  State<ClientMyJobsPage> createState() => _ClientMyJobsPageState();
}

class _ClientMyJobsPageState extends State<ClientMyJobsPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  /// status filter:
  /// 0 solicitados, 1 andamento, 2 realizados, 3 cancelados, 4 reclamações
  int _selectedStatusFilter = 0;

  /// filtro de dias (começa em 7)
  final List<int> _filterOptions = [7, 14, 30, 60, 90];
  int _selectedDays = 7;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// listas “prontas” (padrão provider)
  List<Map<String, dynamic>> _requestedItems = [];
  List<Map<String, dynamic>> _inProgressItems = [];
  List<Map<String, dynamic>> _completedItems = [];
  List<Map<String, dynamic>> _cancelledItems = [];
  List<Map<String, dynamic>> _disputeItems = [];

  int _countRequested = 0;
  int _countInProgress = 0;
  int _countCompleted = 0;
  int _countCancelled = 0;
  int _countDisputes = 0;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _sinceUtc() =>
      DateTime.now().toUtc().subtract(Duration(days: _selectedDays));

  // =============================================================
  // LOAD (1 query)
  // =============================================================
  Future<void> _loadJobs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;

      _requestedItems = [];
      _inProgressItems = [];
      _completedItems = [];
      _cancelledItems = [];
      _disputeItems = [];

      _countRequested = 0;
      _countInProgress = 0;
      _countCompleted = 0;
      _countCancelled = 0;
      _countDisputes = 0;

      // Mantém filtro selecionado, só limpa busca
      _searchTerm = '';
      _searchController.clear();
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Faça login novamente para ver seus pedidos.';
      });
      return;
    }

    try {
      final since = _sinceUtc().toIso8601String();
      final prefs = await SharedPreferences.getInstance();

// 1) Reclamações SEM filtro de dias
      final disputesRes = await supabase
          .from('v_client_my_jobs_dashboard')
          .select('''
      job_id,
      title,
      description,
      status,
      created_at,
      job_code,
      quotes_count,
      new_candidates_count,
      dispute_status
    ''')
          .or('dispute_status.eq.open,dispute_status.eq.resolved')
          .order('created_at', ascending: false);

// 2) Demais jobs COM filtro de dias (exclui disputas)
      final jobsRes = await supabase
          .from('v_client_my_jobs_dashboard')
          .select('''
      job_id,
      title,
      description,
      status,
      created_at,
      job_code,
      quotes_count,
      new_candidates_count,
      dispute_status
    ''')
          .gte('created_at', since)
          .not('dispute_status', 'in', '("open","resolved")')
          .order('created_at', ascending: false);

// 3) Junta e remove duplicados (pelo job_id)
      final Map<String, Map<String, dynamic>> byId = {};

      for (final row in (jobsRes as List<dynamic>)) {
        final r = Map<String, dynamic>.from(row as Map);
        final id = r['job_id']?.toString();
        if (id != null) byId[id] = r;
      }

      for (final row in (disputesRes as List<dynamic>)) {
        final r = Map<String, dynamic>.from(row as Map);
        final id = r['job_id']?.toString();
        if (id != null) byId[id] = r;
      }

      final rows = byId.values.toList();

      // Normaliza + aplica regra de “novos candidatos”
      final normalized = <Map<String, dynamic>>[];

      for (final r in rows) {
        final jobId = r['job_id']?.toString();
        if (jobId == null || jobId.isEmpty) continue;

        final totalQuotes = (r['quotes_count'] as num?)?.toInt() ?? 0;
        final totalCandidates =
            (r['new_candidates_count'] as num?)?.toInt() ?? 0;

        // ✅ se nunca viu, seen = 0 => tudo é novo
        final seen = prefs.getInt('client_seen_candidates_$jobId') ?? 0;
        int delta = totalCandidates - seen;
        if (delta < 0) delta = 0;

        normalized.add({
          ...r,
          'id': jobId,
          'quotes_count': totalQuotes,
          'candidates_total': totalCandidates, // total bruto
          'new_candidates_count': delta, // delta visto
          'dispute_status': (r['dispute_status'] as String?) ?? '',
        });
      }

      // Categoriza (uma vez só)
      final requested = <Map<String, dynamic>>[];
      final inProgress = <Map<String, dynamic>>[];
      final completed = <Map<String, dynamic>>[];
      final cancelled = <Map<String, dynamic>>[];
      final disputes = <Map<String, dynamic>>[];

      for (final j in normalized) {
        final status = (j['status'] as String?) ?? '';
        final disputeStatus = (j['dispute_status'] as String?) ?? '';

        final hasDispute =
            disputeStatus == 'open' || disputeStatus == 'resolved';
        if (hasDispute) {
          disputes.add(j);
          continue;
        }

        if (status == 'open' || status == 'waiting_providers') {
          requested.add(j);
          continue;
        }

        if (['accepted', 'on_the_way', 'in_progress', 'execution_overdue']
            .contains(status)) {
          inProgress.add(j);
          continue;
        }

        if (['completed', 'refunded'].contains(status)) {
          completed.add(j);
          continue;
        }

        if (['cancelled', 'cancelled_by_client', 'cancelled_by_provider']
            .contains(status)) {
          cancelled.add(j);
          continue;
        }

        // fallback
        inProgress.add(j);
      }

      // ✅ Ordenação dos “Solicitados”:
      // 1) primeiro os waiting_providers com novos candidatos (delta>0)
      // 2) depois maior delta
      // 3) depois mais recente
      requested.sort((a, b) {
        final aStatus = (a['status'] as String?) ?? '';
        final bStatus = (b['status'] as String?) ?? '';

        final aDelta = aStatus == 'waiting_providers'
            ? ((a['new_candidates_count'] as int?) ?? 0)
            : 0;
        final bDelta = bStatus == 'waiting_providers'
            ? ((b['new_candidates_count'] as int?) ?? 0)
            : 0;

        final aHas = aDelta > 0;
        final bHas = bDelta > 0;

        if (aHas != bHas) return bHas ? 1 : -1; // b com novos sobe

        final byDelta = bDelta.compareTo(aDelta);
        if (byDelta != 0) return byDelta;

        final aDt = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime(1970);
        final bDt = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime(1970);
        return bDt.compareTo(aDt);
      });

      setState(() {
        _requestedItems = requested;
        _inProgressItems = inProgress;
        _completedItems = completed;
        _cancelledItems = cancelled;
        _disputeItems = disputes;

        _countRequested = requested.length;
        _countInProgress = inProgress.length;
        _countCompleted = completed.length;
        _countCancelled = cancelled.length;
        _countDisputes = disputes.length;

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar ClientMyJobs (dashboard view): $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Erro ao carregar seus pedidos.';
      });
    }
  }

  // =============================================================
  // Mark as seen (candidatos)
  // =============================================================
  Future<void> _markCandidatesSeen(Map<String, dynamic> job) async {
    final jobId = job['id']?.toString();
    if (jobId == null || jobId.isEmpty) return;

    final total = (job['candidates_total'] as int?) ?? 0;
    final prefs = await SharedPreferences.getInstance();
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
    ).then((_) => _loadJobs());
  }

  // =============================================================
  // Helpers
  // =============================================================
  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return _dateFormat.format(dt);
    } catch (_) {
      return iso;
    }
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> jobs) {
    if (_searchTerm.isEmpty) return jobs;
    return jobs.where((job) {
      final title = (job['title'] as String? ?? '').toLowerCase();
      final desc = (job['description'] as String? ?? '').toLowerCase();
      return title.contains(_searchTerm) || desc.contains(_searchTerm);
    }).toList();
  }

  String _statusLabel(String status) {
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

  Color _statusColor(String status) {
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

  List<Map<String, dynamic>> _itemsForSelectedGroup() {
    switch (_selectedStatusFilter) {
      case 0:
        return _requestedItems;
      case 1:
        return _inProgressItems;
      case 2:
        return _completedItems;
      case 3:
        return _cancelledItems;
      case 4:
        return _disputeItems;
      default:
        return _requestedItems;
    }
  }

  // Cards topo
  List<Map<String, dynamic>> _jobsWithOpenDisputes() {
    return _disputeItems.where((job) {
      final ds = (job['dispute_status'] as String?) ?? '';
      return ds == 'open';
    }).toList();
  }

  List<Map<String, dynamic>> _jobsWithNewQuotes() {
    return _requestedItems.where((job) {
      final status = (job['status'] as String?) ?? '';
      final quotesCount = (job['quotes_count'] as int?) ?? 0;

      final isOpen = status == 'open' || status == 'waiting_providers';
      return isOpen && quotesCount > 0;
    }).toList();
  }

  // =============================================================
  // BUILD
  // =============================================================
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
                  ? _buildLoadingSkeleton()
                  : errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadJobs,
                          child: _buildDashboard(),
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

  Widget _buildDashboard() {
    final total = _countRequested +
        _countInProgress +
        _countCompleted +
        _countCancelled +
        _countDisputes;

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

    final hasDisputes = _jobsWithOpenDisputes().isNotEmpty;
    final hasQuotes = _jobsWithNewQuotes().isNotEmpty;

    final baseJobs = _itemsForSelectedGroup();
    final visibleJobs = _applySearch(baseJobs);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (hasDisputes) _buildDisputeCard(),
        if (hasDisputes && hasQuotes) const SizedBox(height: 12),
        if (hasQuotes) _buildNewQuotesCard(),
        if (hasDisputes || hasQuotes) const SizedBox(height: 20),
        _buildSearchField(),
        const SizedBox(height: 12),
        _buildStatusFilterRow(),
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
          ...visibleJobs.map(_buildJobCard),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------- SEARCH ----------------

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

  // ---------------- CARDS DO TOPO ----------------

  Widget _buildDisputeCard() {
    final disputeJobs = _jobsWithOpenDisputes();
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

  Widget _buildNewQuotesCard() {
    final jobsWithQuotes = _jobsWithNewQuotes();
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

  // ---------------- FILTROS ----------------

  Widget _buildStatusFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatusFilterChip(
            label: 'Solicitados',
            count: _countRequested,
            isSelected: _selectedStatusFilter == 0,
            color: const Color(0xFF0DAA00),
            icon: Icons.assignment_outlined,
            onTap: () => setState(() => _selectedStatusFilter = 0),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Em andamento',
            count: _countInProgress,
            isSelected: _selectedStatusFilter == 1,
            color: const Color(0xFFFF6600),
            icon: Icons.play_arrow_rounded,
            onTap: () => setState(() => _selectedStatusFilter = 1),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Realizados',
            count: _countCompleted,
            isSelected: _selectedStatusFilter == 2,
            color: const Color(0xFF3B246B),
            icon: Icons.check_circle_outline,
            onTap: () => setState(() => _selectedStatusFilter = 2),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Cancelados',
            count: _countCancelled,
            isSelected: _selectedStatusFilter == 3,
            color: Colors.grey,
            icon: Icons.close_rounded,
            onTap: () => setState(() => _selectedStatusFilter = 3),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            label: 'Reclamações',
            count: _countDisputes,
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
                _loadJobs();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- CARD DO JOB ----------------

  Widget _buildJobCard(Map<String, dynamic> j) {
    final title = (j['title'] as String?) ?? 'Serviço';
    final description = (j['description'] as String?) ?? '';
    final displayTitle = description.isNotEmpty ? description : title;
    final jobCode = (j['job_code'] as String?) ?? '';

    final status = (j['status'] as String?) ?? '';
    final createdAt = j['created_at']?.toString();

    final int quotesCount = (j['quotes_count'] as int?) ?? 0;
    final bool hasQuotes = quotesCount > 0;

    // ✅ Só mostra novos candidatos quando status == waiting_providers
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
            // Job Code Display
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

            // ✅ Info pills
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

// ------------------------------------------------------------
// COMPONENTES AUXILIARES (mantidos do seu estilo)
// ------------------------------------------------------------

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
