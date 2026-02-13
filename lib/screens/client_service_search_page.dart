// lib/screens/client_service_search_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

const _kRoxo = Color(0xFF3B246B);

class ClientServiceSearchPage extends ConsumerStatefulWidget { // se true, já carrega todos os serviços

  const ClientServiceSearchPage({
    super.key,
    this.showAllOnStart = false,
  });
  final bool showAllOnStart;

  @override
  ConsumerState<ClientServiceSearchPage> createState() =>
      _ClientServiceSearchPageState();
}

class _ClientServiceSearchPageState extends ConsumerState<ClientServiceSearchPage> {

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    if (widget.showAllOnStart) {
      _loadServices('');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadServices(value.trim());
    });
  }

  Future<void> _loadServices(String query) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      const selectCols =
          'id, name, description, category:service_categories(name)';

      List<dynamic> rows;

      // Tela normal de busca: se estiver vazio, não carrega nada
      if (!widget.showAllOnStart && query.isEmpty) {
        setState(() {
          _results = [];
          _loading = false;
        });
        return;
      }

      if (query.isEmpty) {
        // showAllOnStart = true -> carrega tudo
        final supabase = ref.read(supabaseProvider);
        rows = await supabase
            .from('service_types')
            .select(selectCols)
            .eq('is_active', true)
            .order('sort_order', ascending: true);
      } else {
        final supabase = ref.read(supabaseProvider);
        final pattern = '%$query%';

        // Busca por name
        final byName = await supabase
            .from('service_types')
            .select(selectCols)
            .eq('is_active', true)
            .ilike('name', pattern)
            .order('sort_order', ascending: true);

        // Busca por description
        final byDescription = await supabase
            .from('service_types')
            .select(selectCols)
            .eq('is_active', true)
            .ilike('description', pattern)
            .order('sort_order', ascending: true);

        // Junta resultados, evitando duplicados (por id)
        final Map<String, Map<String, dynamic>> byId = {};
        for (final row in [...byName, ...byDescription]) {
          final m = row;
          final id = (m['id'] ?? '').toString();
          if (id.isEmpty) continue;
          byId[id] = m;
        }
        rows = byId.values.toList();
      }

      if (!mounted) return;

      _results = (rows).cast<Map<String, dynamic>>();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectService(Map<String, dynamic> row) {
    final name = (row['name'] ?? '').toString();
    if (name.isEmpty) return;
    Navigator.of(context).pop<String>(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kRoxo,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: !widget.showAllOnStart,
          onChanged: _onTextChanged,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: const InputDecoration(
            hintText: 'Buscar serviço (ex: eletricista)',
            hintStyle: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            border: InputBorder.none,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Não foi possível carregar os serviços.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _loadServices(_controller.text.trim());
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Digite o serviço que você precisa\n(ex: pedreiro, eletricista, diarista)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      );
    }

    // ✅ apresentação em chips (serve tanto pra busca quanto pra "ver todos")
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _results.map((row) {
          final name = (row['name'] ?? '').toString();
          final desc = (row['description'] ?? '').toString();
          final category =
              ((row['category'] ?? {}) as Map<String, dynamic>)['name']
                  ?.toString();

          return ActionChip(
            onPressed: () => _selectService(row),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 80,
                maxWidth: 220,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (category != null && category.isNotEmpty)
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _kRoxo,
                      ),
                    ),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
