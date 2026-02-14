// lib/screens/search_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/exceptions/app_exceptions.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/features/search/data/providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  String? _category;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 15;
  List<dynamic> _services = [];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore && !_loading) {
      _loadMore();
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _loadServices());
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _page = 0;
      _hasMore = true;
    });
    try {
      final repo = ref.read(searchRepositoryProvider);
      final res = await repo.searchServices(
        query: _searchCtrl.text.trim(),
        categoryId: _category,
        from: 0,
        to: _pageSize - 1,
      );
      if (!mounted) return;
      setState(() {
        _services = res;
        _hasMore = res.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showSnackBar(context, parseSupabaseException(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(searchRepositoryProvider);
      final from = (_page + 1) * _pageSize;
      final to = from + _pageSize - 1;
      final newItems = await repo.searchServices(
        query: _searchCtrl.text.trim(),
        categoryId: _category,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _services.addAll(newItems);
        _page++;
        _hasMore = newItems.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showSnackBar(context, parseSupabaseException(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _createBooking(Map<String, dynamic> service) async {
    final client = ref.read(supabaseProvider);
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para agendar um serviço')),
      );
      return;
    }
    final providerId = service['provider_id']?.toString();
    if (providerId == null || providerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço sem prestador vinculado')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar agendamento'),
        content: Text(
          'Deseja solicitar o serviço "${service['name']}" para o prestador?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(searchRepositoryProvider);
      await repo.createBooking(
        serviceId: service['id'].toString(),
        providerId: providerId,
        clientId: user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido criado com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showSnackBar(context, parseSupabaseException(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar serviços'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'O que você procura?',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _loadServices(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loadServices,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String?>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todas')),
                DropdownMenuItem(value: 'cleaning', child: Text('Limpeza')),
                DropdownMenuItem(value: 'construction', child: Text('Pedreiro')),
                DropdownMenuItem(value: 'moving', child: Text('Fretes')),
                DropdownMenuItem(value: 'other', child: Text('Outros')),
              ],
              onChanged: (String? v) {
                setState(() => _category = v);
                _loadServices();
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _services.isEmpty
                    ? const Center(child: Text('Nenhum serviço encontrado'))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: _services.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _services.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final s = _services[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6,),
                            child: ListTile(
                              title: Text(s['name'] ?? 'Serviço'),
                              subtitle: Text(
                                (s['description'] ?? '') +
                                    '\nValor: R\$ ${s['price'] ?? '--'}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () => _createBooking(
                                  Map<String, dynamic>.from(s),),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
