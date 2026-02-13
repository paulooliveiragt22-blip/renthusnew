// lib/screens/search_services.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class SearchServicesScreen extends ConsumerStatefulWidget {
  const SearchServicesScreen({super.key});

  @override
  ConsumerState<SearchServicesScreen> createState() => _SearchServicesScreenState();
}

class _SearchServicesScreenState extends ConsumerState<SearchServicesScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  String _query = '';
  String? _selectedCategory;
  String _sortBy = 'unit';
  bool _asc = true;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 10;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadFirstPage();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ======== CATEGORIAS =========
  Future<void> _loadCategories() async {
    try {
      final client = ref.read(supabaseProvider);
      final res = await client.from('service_categories').select('id, name').order('name');
      if (res != null && res is List) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(res.map((e) => Map<String, dynamic>.from(e)));
        });
      }
    } catch (e) {
      debugPrint('Erro carregando categorias: $e');
    }
  }

  // ======== BUSCA/PAGINAÇÃO =========
  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _hasMore = true;
      _items = [];
    });
    try {
      final data = await _fetchPage(0);
      setState(() {
        _items = data;
        _hasMore = data.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao carregar serviços: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final data = await _fetchPage(nextPage);
      setState(() {
        _page = nextPage;
        _items.addAll(data);
        _hasMore = data.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro carregando mais: $e')));
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    final from = page * _pageSize;
    final to = (page + 1) * _pageSize - 1;

    final client = ref.read(supabaseProvider);
    var queryBuilder = client
        .from('services_catalog')
        .select('id, unit, categoria_id, dispute_hours, created_at, update_at');

    if (_query.trim().isNotEmpty) {
      queryBuilder = queryBuilder.ilike('unit', '%${_query.trim()}%');
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      queryBuilder = queryBuilder.eq('categoria_id', _selectedCategory);
    }

    queryBuilder = queryBuilder.order(_sortBy, ascending: _asc).range(from, to);

    final res = await queryBuilder;
    if (res == null) return [];
    if (res is List) {
      return List<Map<String, dynamic>>.from(res.map((e) => Map<String, dynamic>.from(e)));
    }
    return [];
  }

  // ======== HANDLERS =========
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _query = text;
      _loadFirstPage();
    });
  }

  void _applyCategory(String? categoryId) {
    setState(() {
      _selectedCategory = categoryId;
    });
    _loadFirstPage();
  }

  void _toggleSort() {
    setState(() => _asc = !_asc);
    _loadFirstPage();
  }

  // ======== UI =========
  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Pesquisar por nome do serviço...', prefixIcon: Icon(Icons.search)),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Limpar filtros',
              onPressed: () {
                setState(() {
                  _query = '';
                  _selectedCategory = null;
                  _sortBy = 'unit';
                  _asc = true;
                });
                _loadFirstPage();
              },
              icon: const Icon(Icons.clear_all),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            DropdownButton<String>(
              value: _selectedCategory,
              hint: const Text('Filtrar por categoria'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ..._categories
                    .map((c) => DropdownMenuItem(
                          value: c['id']?.toString(),
                          child: Text(c['name'] ?? '—'),
                        ))
                    .toList(),
              ],
              onChanged: _applyCategory,
            ),
            DropdownButton<String>(
              value: _sortBy,
              items: const [
                DropdownMenuItem(value: 'unit', child: Text('Ordenar por nome')),
                DropdownMenuItem(value: 'created_at', child: Text('Mais recentes')),
              ],
              onChanged: (v) {
                setState(() => _sortBy = v ?? 'unit');
                _loadFirstPage();
              },
            ),
            IconButton(
              tooltip: 'Alternar ordem',
              icon: Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: _toggleSort,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_items.isEmpty) {
      return const Expanded(child: Center(child: Text('Nenhum serviço encontrado.')));
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView.builder(
          controller: _scrollCtrl,
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index < _items.length) {
              final s = _items[index];
              return _buildTile(s);
            } else if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (!_hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Fim da lista')),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> s) {
    final id = s['id']?.toString() ?? '';
    final nome = s['unit']?.toString() ?? '—';
    final horas = s['dispute_hours']?.toString() ?? '—';
    final categoria = s['categoria_id']?.toString() ?? '';
    final criado = s['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.home_repair_service),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Duração: $horas horas'),
          Text('Categoria ID: $categoria'),
          Text('Criado em: $criado'),
        ]),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/booking_details', arguments: {'serviceId': id});
          },
          child: const Text('Ver detalhes'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar Serviços')),
      body: Column(
        children: [
          _buildFilters(),
          _buildList(),
        ],
      ),
    );
  }
}
