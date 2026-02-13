import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class ProviderFinancialPage extends ConsumerStatefulWidget {
  const ProviderFinancialPage({super.key});

  @override
  ConsumerState<ProviderFinancialPage> createState() => _ProviderFinancialPageState();
}

class _ProviderFinancialPageState extends ConsumerState<ProviderFinancialPage> {

  bool isLoading = true;
  bool hasError = false;

  double availableBalance =
      0.0; // não é mais exibido no resumo, mas mantido para futuro
  double pendingBalance =
      0.0; // a liberar (jobs completed sem payment_released_at)
  double monthEarnings = 0.0; // ganhos no mês (já liberado)

  List<PaidJob> paidJobs = []; // últimos serviços pagos

  // --- EXTRATO ---
  int selectedTab = 0; // 0 = Resumo, 1 = Extrato
  List<StatementEntry> _allStatementEntries = [];
  List<StatementEntry> _filteredStatementEntries = [];
  DateTime? _filterStart;
  DateTime? _filterEnd;
  String _typeFilter = 'todos'; // todos, entrada, saida

  // Formatação BRL
  final NumberFormat _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
        return;
      }

      // 🔑 1) Buscar provider pelo user_id (regra oficial do Renthus)
      final providerRow = await supabase
          .from('providers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (providerRow == null || providerRow['id'] == null) {
        // sem cadastro de prestador => não calcula nada, mas não quebra
        setState(() {
          isLoading = false;
          hasError = true;
          availableBalance = 0.0;
          pendingBalance = 0.0;
          monthEarnings = 0.0;
          paidJobs = [];
          _allStatementEntries = [];
          _filteredStatementEntries = [];
        });
        return;
      }

      final providerId = providerRow['id'];

      // 🔍 2) Buscar jobs em que este provider (providers.id) foi o escolhido
      final result = await supabase
          .from('jobs')
          .select(
            'id, title, provider_amount, status, payment_released_at, created_at',
          )
          .eq('provider_id', providerId);

      double available = 0;
      double pending = 0;
      double month = 0;
      final now = DateTime.now();

      final List<PaidJob> tempPaid = [];

      for (final row in result as List<dynamic>) {
        final amount = (row['provider_amount'] as num?)?.toDouble() ?? 0.0;
        final status = row['status'] as String? ?? '';
        final String? releasedStr = row['payment_released_at'] as String?;
        final String title = row['title'] as String? ?? 'Serviço';

        DateTime? releasedAt =
            releasedStr != null ? DateTime.parse(releasedStr).toLocal() : null;

        if (releasedAt != null) {
          // valor já liberado
          available += amount;

          if (releasedAt.year == now.year && releasedAt.month == now.month) {
            month += amount;
          }

          tempPaid.add(
            PaidJob(
              id: row['id'].toString(),
              title: title,
              amount: amount,
              releasedAt: releasedAt,
            ),
          );
        } else {
          // ainda não liberado: serviços finalizados aguardando prazo
          if (status == 'completed') {
            pending += amount;
          }
        }
      }

      tempPaid.sort((a, b) => b.releasedAt.compareTo(a.releasedAt));

      // monta extrato (por enquanto só ENTRADAS; saídas virão quando tivermos tabela de saques)
      final List<StatementEntry> entries = tempPaid
          .map(
            (pj) => StatementEntry(
              id: pj.id,
              type: 'entrada',
              amount: pj.amount,
              date: pj.releasedAt,
              description: pj.title,
            ),
          )
          .toList();

      // período padrão = últimos 90 dias
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final start = end.subtract(const Duration(days: 90));

      setState(() {
        availableBalance = available;
        pendingBalance = pending;
        monthEarnings = month;
        paidJobs = tempPaid;

        _allStatementEntries = entries;
        _filterStart = start;
        _filterEnd = end;
        _applyFilters();

        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar financeiro: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        availableBalance = 0.0;
        pendingBalance = 0.0;
        monthEarnings = 0.0;
        paidJobs = [];
        _allStatementEntries = [];
        _filteredStatementEntries = [];
      });
    }
  }

  // --------- FILTROS DO EXTRATO ---------

  void _applyFilters() {
    List<StatementEntry> list = List.from(_allStatementEntries);

    if (_filterStart != null) {
      list = list
          .where((e) => !e.date.isBefore(DateTime(
              _filterStart!.year, _filterStart!.month, _filterStart!.day)))
          .toList();
    }

    if (_filterEnd != null) {
      list = list
          .where((e) => !e.date.isAfter(DateTime(
              _filterEnd!.year, _filterEnd!.month, _filterEnd!.day, 23, 59)))
          .toList();
    }

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
    final initial = _filterStart ?? now.subtract(const Duration(days: 90));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Selecione a data inicial',
    );

    if (picked != null) {
      setState(() {
        _filterStart = picked;
      });
      _applyFilters();
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _filterEnd ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Selecione a data final',
    );

    if (picked != null) {
      setState(() {
        _filterEnd = picked;
      });
      _applyFilters();
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        final data = _formatDate(e.date);
        final tipo = e.type == 'entrada' ? 'Entrada' : 'Saída';
        final desc = e.description.replaceAll(';', ',');
        final valor = e.amount.toStringAsFixed(2).replaceAll('.', ',');

        buffer.writeln('$data;$tipo;$desc;$valor');
      }

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now();
      final name =
          'extrato_renthus_${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}.csv';
      final file = File('${dir.path}/$name');

      await file.writeAsString(buffer.toString(), flush: true);

      _showSnack('CSV salvo em: ${file.path}');
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

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Text(
                'Extrato Financeiro - Renthus',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Gerado em ${_formatDate(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Data', 'Tipo', 'Descrição', 'Valor'],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
                cellAlignment: pw.Alignment.centerLeft,
                data: _filteredStatementEntries.map((e) {
                  final tipo = e.type == 'entrada' ? 'Entrada' : 'Saída';
                  final valor =
                      'R\$ ${e.amount.toStringAsFixed(2).replaceAll('.', ',')}';
                  return [
                    _formatDate(e.date),
                    tipo,
                    e.description,
                    valor,
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now();
      final name =
          'extrato_renthus_${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}.pdf';
      final file = File('${dir.path}/$name');

      await file.writeAsBytes(await pdf.save());

      _showSnack('PDF salvo em: ${file.path}');
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Não foi possível carregar os dados agora.\n'
                  'Tente novamente mais tarde.',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFinancialData,
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
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTab = 0;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color:
                      selectedTab == 0 ? const Color(0xFF3B246B) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: const Border(
                    bottom: BorderSide(
                      color: Color(0xFF3B246B),
                      width: 1,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Resumo',
                    style: TextStyle(
                      color: selectedTab == 0 ? Colors.white : Colors.black87,
                      fontWeight:
                          selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTab = 1;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color:
                      selectedTab == 1 ? const Color(0xFF3B246B) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: const Border(
                    bottom: BorderSide(
                      color: Color(0xFF3B246B),
                      width: 1,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Extrato',
                    style: TextStyle(
                      color: selectedTab == 1 ? Colors.white : Colors.black87,
                      fontWeight:
                          selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
        // Card principal: Ganhos no mês
        _buildBalanceCard(
          title: 'Ganhos no mês',
          value: monthEarnings,
          description: 'Total que já caiu na sua conta neste mês.',
          valueColor: const Color(0xFF3B246B),
        ),
        const SizedBox(height: 12),
        // Card menor: Saldo a liberar
        _buildMiniBalanceCard(
          title: 'Saldo a liberar',
          value: pendingBalance,
          description: 'Serviços finalizados aguardando o prazo de 24h/72h.',
          valueColor: const Color(0xFFFF6600),
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
          ...paidJobs.take(10).map(_buildPaidJobTile),
      ],
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double value,
    required String description,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyBr.format(value),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Card menor (metade da altura aproximada)
  Widget _buildMiniBalanceCard({
    required String title,
    required double value,
    required String description,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currencyBr.format(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidJobTile(PaidJob job) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
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
                  job.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(job.releasedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currencyBr.format(job.amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B246B),
            ),
          ),
        ],
      ),
    );
  }

  // --------- EXTRATO (aba 1) ---------

  Widget _buildExtratoListView() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildExtratoFilters(),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: _filteredStatementEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredStatementEntries[index];
                    final isEntrada = entry.type == 'entrada';
                    final color = isEntrada ? Colors.green : Colors.red;

                    final formattedAmount = _currencyBr.format(entry.amount);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.04),
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
                                (isEntrada ? '+ ' : '- ') + formattedAmount,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    startLabel,
                    style: const TextStyle(color: Color(0xFF3B246B)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickEndDate,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3B246B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    endLabel,
                    style: const TextStyle(color: Color(0xFF3B246B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _typeFilter,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'todos',
                      child: Text('Todos'),
                    ),
                    DropdownMenuItem(
                      value: 'entrada',
                      child: Text('Entradas'),
                    ),
                    DropdownMenuItem(
                      value: 'saida',
                      child: Text('Saídas'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _typeFilter = value;
                    });
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text(
                  'CSV',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _exportPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B246B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text(
                  'PDF',
                  style: TextStyle(fontSize: 13),
                ),
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
  final String id;
  final String title;
  final double amount;
  final DateTime releasedAt;

  PaidJob({
    required this.id,
    required this.title,
    required this.amount,
    required this.releasedAt,
  });
}

class StatementEntry {
  final String id;
  final String type; // 'entrada' ou 'saida'
  final double amount;
  final DateTime date;
  final String description;

  StatementEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
  });
}
