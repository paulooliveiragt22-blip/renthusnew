import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';

class ProviderFinancialPage extends ConsumerStatefulWidget {
  const ProviderFinancialPage({super.key});

  @override
  ConsumerState<ProviderFinancialPage> createState() =>
      _ProviderFinancialPageState();
}

class _ProviderFinancialPageState extends ConsumerState<ProviderFinancialPage> {
  bool isLoading = true;
  bool hasError = false;

  // Resumo
  double releasedBalance = 0.0;
  double pendingBalance = 0.0;
  double pendingExecutionBalance = 0.0;
  double pendingReleaseBalance = 0.0;
  double monthEarnings = 0.0;
  int releasedJobsCount = 0;
  int pendingJobsCount = 0;

  List<PaidJob> paidJobs = [];

  // Extrato
  int selectedTab = 0;
  List<StatementEntry> _allStatementEntries = [];
  List<StatementEntry> _filteredStatementEntries = [];
  DateTime? _filterStart;
  DateTime? _filterEnd;
  String _typeFilter = 'todos';

  final NumberFormat _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _initDefaultDates();
    _loadFinancialData();
  }

  void _initDefaultDates() {
    final now = DateTime.now();
    _filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _filterStart = _filterEnd!.subtract(const Duration(days: 90));
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final supabase = ref.read(supabaseProvider);

      // Paralelo: summary + released jobs com filtro de data no SQL
      final results = await Future.wait([
        supabase.rpc('get_provider_financial_summary'),
        supabase.rpc('get_provider_financial_released_jobs', params: {
          'p_limit': 500,
          'p_start_date': _filterStart?.toUtc().toIso8601String(),
          'p_end_date': _filterEnd?.toUtc().toIso8601String(),
        }),
      ]);

      final summaryRes = results[0];
      final releasedJobsRes = results[1];

      final summary = _readFirstRow(summaryRes);

      final List<PaidJob> tempPaid = [];
      if (releasedJobsRes is List) {
        for (final raw in releasedJobsRes) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          final releasedAtRaw = row['released_at'];
          DateTime? releasedAt;
          if (releasedAtRaw != null) {
            releasedAt = DateTime.tryParse(releasedAtRaw.toString())?.toLocal();
          }
          if (releasedAt == null) continue;
          final jobCode = (row['job_code'] ?? '').toString();
          final title = (row['title'] ?? '').toString();
          final label = jobCode.isNotEmpty ? '$jobCode — $title' : (title.isNotEmpty ? title : 'Serviço');
          tempPaid.add(PaidJob(
            id: (row['job_id'] ?? '').toString(),
            label: label,
            amount: _toDouble(row['amount']),
            releasedAt: releasedAt,
          ));
        }
      }

      final List<StatementEntry> entries = tempPaid
          .map((pj) => StatementEntry(
                id: pj.id,
                type: 'entrada',
                amount: pj.amount,
                date: pj.releasedAt,
                description: pj.label,
              ))
          .toList();

      setState(() {
        releasedBalance = _toDouble(summary?['released_total']);
        pendingBalance = _toDouble(summary?['pending_total']);
        pendingExecutionBalance = _toDouble(summary?['pending_execution_total']);
        pendingReleaseBalance = _toDouble(summary?['pending_release_total']);
        monthEarnings = _toDouble(summary?['month_released_total']);
        releasedJobsCount = _toInt(summary?['released_jobs_count']);
        pendingJobsCount = _toInt(summary?['pending_jobs_count']);
        paidJobs = tempPaid;
        _allStatementEntries = entries;
        _applyFilters();
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar financeiro: $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  Map<String, dynamic>? _readFirstRow(dynamic res) {
    if (res == null) return null;
    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    return null;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  void _applyFilters() {
    List<StatementEntry> list = List.from(_allStatementEntries);

    if (_typeFilter != 'todos') {
      list = list.where((e) => e.type == _typeFilter).toList();
    }

    list.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _filteredStatementEntries = list;
    });
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterStart ?? now.subtract(const Duration(days: 90)),
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Selecione a data inicial',
    );
    if (picked != null) {
      setState(() => _filterStart = picked);
      await _loadFinancialData();
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterEnd ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Selecione a data final',
    );
    if (picked != null) {
      setState(() => _filterEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
      await _loadFinancialData();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --------- EXPORTAÇÃO CSV ---------

  Future<void> _exportCsv() async {
    if (_filteredStatementEntries.isEmpty) {
      _showSnack('Não há lançamentos para exportar.');
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Data;Tipo;Descrição;Valor');
      for (final e in _filteredStatementEntries) {
        final tipo = e.type == 'entrada' ? 'Entrada' : 'Saída';
        final desc = e.description.replaceAll(';', ',');
        final valor = e.amount.toStringAsFixed(2).replaceAll('.', ',');
        buffer.writeln('${_formatDate(e.date)};$tipo;$desc;$valor');
      }

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now();
      final name = 'extrato_renthus_'
          '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}'
          '_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}.csv';
      final file = File('${dir.path}/$name');
      await file.writeAsString(buffer.toString(), flush: true);

      await Share.shareXFiles([XFile(file.path)], text: 'Extrato Renthus');
    } catch (e) {
      debugPrint('Erro ao exportar CSV: $e');
      _showSnack('Erro ao exportar CSV.');
    }
  }

  // --------- EXPORTAÇÃO PDF ---------

  Future<void> _exportPdf() async {
    if (_filteredStatementEntries.isEmpty) {
      _showSnack('Não há lançamentos para exportar.');
      return;
    }

    try {
      final pdf = pw.Document();
      final total = _filteredStatementEntries.fold(0.0, (sum, e) => sum + e.amount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'Extrato Financeiro - Renthus',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Gerado em ${_formatDate(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Data', 'Tipo', 'Descrição', 'Valor'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
              cellAlignment: pw.Alignment.centerLeft,
              data: _filteredStatementEntries.map((e) {
                final tipo = e.type == 'entrada' ? 'Entrada' : 'Saída';
                final valor = 'R\$ ${e.amount.toStringAsFixed(2).replaceAll('.', ',')}';
                return [_formatDate(e.date), tipo, e.description, valor];
              }).toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now();
      final name = 'extrato_renthus_'
          '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}'
          '_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Extrato Renthus');
    } catch (e) {
      debugPrint('Erro ao exportar PDF: $e');
      _showSnack('Erro ao exportar PDF.');
    }
  }

  // --------- UI ---------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabSwitcher(),
            if (hasError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Não foi possível carregar os dados agora.\nTente novamente mais tarde.',
                  style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFinancialData,
                color: const Color(0xFF3B246B),
                child: selectedTab == 0
                    ? _buildResumoListView()
                    : _buildExtratoListView(),
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
      color: const Color(0xFF3B246B),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: const Text(
        'Financeiro',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF2F2F2),
      child: Row(
        children: [
          Expanded(child: _buildTab('Resumo', 0)),
          const SizedBox(width: 8),
          Expanded(child: _buildTab('Extrato', 1)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B246B) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF3B246B), width: 1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // --------- RESUMO (aba 0) ---------

  Widget _buildResumoListView() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Banner informativo sobre transferência automática
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF3B246B).withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3B246B).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFF3B246B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seu saldo liberado é transferido automaticamente para sua conta todo dia útil.',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF3B246B).withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildBalanceCard(
          title: 'Saldo liberado para saque',
          value: releasedBalance,
          subtitle: releasedJobsCount > 0
              ? '$releasedJobsCount ${releasedJobsCount == 1 ? 'serviço' : 'serviços'} liberados'
              : null,
          description: 'Valores de serviços já liberados. Transferência automática diária.',
          valueColor: const Color(0xFF3B246B),
        ),
        const SizedBox(height: 12),
        _buildMiniBalanceCard(
          title: 'Saldo pendente (pago)',
          value: pendingBalance,
          subtitle: pendingJobsCount > 0
              ? '$pendingJobsCount ${pendingJobsCount == 1 ? 'serviço' : 'serviços'} aguardando'
              : null,
          description: 'Pagos pelo cliente, mas ainda não liberados.',
          valueColor: const Color(0xFFFF6600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniBalanceCard(
                title: 'Pendente execução',
                value: pendingExecutionBalance,
                description: 'Pago, mas serviço ainda não finalizado.',
                valueColor: const Color(0xFF0A7AFF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniBalanceCard(
                title: 'Pendente liberação',
                value: pendingReleaseBalance,
                description: 'Finalizado, aguardando liberação.',
                valueColor: const Color(0xFFFF6600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMiniBalanceCard(
          title: 'Ganhos liberados no mês',
          value: monthEarnings,
          description: 'Valores liberados no mês atual.',
          valueColor: const Color(0xFF3B246B),
        ),
        const SizedBox(height: 24),
        const Text(
          'Últimos serviços pagos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3B246B),
          ),
        ),
        const SizedBox(height: 8),
        if (paidJobs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Ainda não há serviços pagos para mostrar aqui.',
              style: TextStyle(fontSize: 14),
            ),
          )
        else
          ...paidJobs.map(_buildPaidJobTile),
      ],
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double value,
    required String description,
    required Color valueColor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            _currencyBr.format(value),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: valueColor),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: valueColor.withOpacity(0.8), fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildMiniBalanceCard({
    required String title,
    required double value,
    required String description,
    required Color valueColor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            _currencyBr.format(value),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: valueColor.withOpacity(0.8), fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildPaidJobTile(PaidJob job) {
    return InkWell(
      onTap: job.id.isNotEmpty ? () => context.pushJobDetails(job.id) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(job.releasedAt),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyBr.format(job.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B246B),
                  ),
                ),
                if (job.id.isNotEmpty)
                  const Text(
                    'Ver detalhes',
                    style: TextStyle(fontSize: 10, color: Color(0xFF3B246B)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------- EXTRATO (aba 1) ---------

  Widget _buildExtratoListView() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _filteredStatementEntries.fold(0.0, (sum, e) => sum + e.amount);

    // Agrupa por mês
    final Map<String, List<StatementEntry>> byMonth = {};
    for (final e in _filteredStatementEntries) {
      final key = DateFormat('MMMM yyyy', 'pt_BR').format(e.date);
      byMonth.putIfAbsent(key, () => []).add(e);
    }

    return Column(
      children: [
        _buildExtratoFilters(),
        if (_filteredStatementEntries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredStatementEntries.length} lançamento(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  'Total: ${_currencyBr.format(total)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B246B),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _filteredStatementEntries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Não há lançamentos no período selecionado.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: byMonth.length,
                  itemBuilder: (context, index) {
                    final monthKey = byMonth.keys.elementAt(index);
                    final entries = byMonth[monthKey]!;
                    final monthTotal = entries.fold(0.0, (s, e) => s + e.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                monthKey[0].toUpperCase() + monthKey.substring(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B246B),
                                ),
                              ),
                              Text(
                                _currencyBr.format(monthTotal),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...entries.map((entry) {
                          final isEntrada = entry.type == 'entrada';
                          final color = isEntrada ? Colors.green : Colors.red;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 6,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.description,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(entry.date),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isEntrada ? '+' : '-'} ${_currencyBr.format(entry.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEntrada ? 'Entrada' : 'Saída',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildExtratoFilters() {
    final startLabel = _filterStart == null
        ? 'Início'
        : '${_filterStart!.day.toString().padLeft(2, '0')}/${_filterStart!.month.toString().padLeft(2, '0')}/${_filterStart!.year}';
    final endLabel = _filterEnd == null
        ? 'Fim'
        : '${_filterEnd!.day.toString().padLeft(2, '0')}/${_filterEnd!.month.toString().padLeft(2, '0')}/${_filterEnd!.year}';

    return Container(
      color: const Color(0xFFF2F2F2),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickStartDate,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3B246B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(startLabel, style: const TextStyle(color: Color(0xFF3B246B))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickEndDate,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3B246B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(endLabel, style: const TextStyle(color: Color(0xFF3B246B))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'entrada', child: Text('Entradas')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _typeFilter = value);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _exportCsv,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3B246B),
                  side: const BorderSide(color: Color(0xFF3B246B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text('CSV', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _exportPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B246B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------- MODELOS ---------

class PaidJob {
  PaidJob({
    required this.id,
    required this.label,
    required this.amount,
    required this.releasedAt,
  });
  final String id;
  final String label;
  final double amount;
  final DateTime releasedAt;
}

class StatementEntry {
  StatementEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
  });
  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final String description;
}
