import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'provider_main_page.dart';

final supabase = Supabase.instance.client;

class ProviderServiceSelectionScreen extends StatefulWidget {
  const ProviderServiceSelectionScreen({super.key});

  @override
  State<ProviderServiceSelectionScreen> createState() =>
      _ProviderServiceSelectionScreenState();
}

class _ProviderServiceSelectionScreenState
    extends State<ProviderServiceSelectionScreen> {
  bool loading = true;

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> serviceTypes = [];

  /// IDs de categorias selecionadas
  final Set<String> selectedCategoryIds = {};

  /// IDs de service_types selecionados
  final Set<String> selectedServiceTypeIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    try {
      // ✅ somente views
      final catsRes = await supabase
          .from('v_service_categories_public')
          .select('id, name, icon, sort_order')
          .order('sort_order');

      final typesRes = await supabase
          .from('v_service_types_public')
          .select('id, name, category_id, sort_order')
          .order('sort_order');

      // ✅ carrega seleção atual do prestador (view)
      final selectedRes = await supabase
          .from('v_provider_service_types_me')
          .select('service_type_id');

      final selectedIds = <String>{
        for (final row in (selectedRes as List<dynamic>))
          if (row['service_type_id'] != null) row['service_type_id'].toString()
      };

      final typeList =
          List<Map<String, dynamic>>.from(typesRes as List<dynamic>);
      final catList = List<Map<String, dynamic>>.from(catsRes as List<dynamic>);

      // marca categorias com base nos types selecionados
      final catIdsFromSelected = <String>{
        for (final t in typeList)
          if (selectedIds.contains(t['id'].toString()))
            t['category_id'].toString()
      };

      if (!mounted) return;
      setState(() {
        categories = catList;
        serviceTypes = typeList;

        selectedServiceTypeIds
          ..clear()
          ..addAll(selectedIds);

        selectedCategoryIds
          ..clear()
          ..addAll(catIdsFromSelected);

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar serviços: $e')),
      );
    }
  }

  IconData _mapCategoryIcon(String icon) {
    switch (icon) {
      case 'car':
        return Icons.directions_car;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'yard':
        return Icons.yard;
      case 'plumbing':
        return Icons.plumbing;
      case 'handyman':
        return Icons.handyman;
      case 'spa':
        return Icons.spa;
      case 'construction':
        return Icons.construction;
      case 'event':
        return Icons.event;
      default:
        return Icons.miscellaneous_services;
    }
  }

  bool _canToggleCategory(String categoryId, bool newValue) {
    if (!newValue) return true;

    final futureSelection = {...selectedCategoryIds}..add(categoryId);
    if (futureSelection.length > 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Você pode selecionar até 2 áreas de serviço.')),
      );
      return false;
    }
    return true;
  }

  bool _canToggleServiceType(Map<String, dynamic> type, bool newValue) {
    if (!newValue) return true;

    final categoryId = type['category_id'] as String;
    final categoryTypes =
        serviceTypes.where((t) => t['category_id'] == categoryId);

    final selectedInCategory = categoryTypes
        .where((t) => selectedServiceTypeIds.contains(t['id'] as String))
        .length;

    if (selectedInCategory >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Em cada área, você pode selecionar até 2 serviços.')),
      );
      return false;
    }

    // limite total de 4
    if (selectedServiceTypeIds.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Você pode selecionar no máximo 4 serviços no total.')),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveAndGoToHome() async {
    if (selectedServiceTypeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um serviço.')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login novamente.')),
      );
      return;
    }

    try {
      // ✅ salva via RPC (SEM providers / provider_service_types no app)
      await supabase.rpc('rpc_provider_set_services', params: {
        'p_service_type_ids': selectedServiceTypeIds.toList(),
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProviderMainPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar serviços: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços que você presta'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Selecione até 2 áreas de serviço e, em cada uma, até 2 serviços que você presta.\n\n'
                    'Você poderá ajustar essa escolha depois no seu perfil.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final catId = cat['id'] as String;

                      final typesOfCat = serviceTypes
                          .where((t) => t['category_id'] == catId)
                          .toList();

                      if (typesOfCat.isEmpty) return const SizedBox.shrink();

                      final selectedTypesOfCat = typesOfCat
                          .where((t) => selectedServiceTypeIds
                              .contains(t['id'] as String))
                          .toList();

                      final bool catExplicitSelected =
                          selectedCategoryIds.contains(catId);
                      final bool catHasSelectedTypes =
                          selectedTypesOfCat.isNotEmpty;
                      final bool catEffectiveSelected =
                          catExplicitSelected || catHasSelectedTypes;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _mapCategoryIcon(
                                        (cat['icon'] as String?) ?? ''),
                                    color: primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cat['name'] as String,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: catEffectiveSelected,
                                    activeColor: primary,
                                    onChanged: (value) {
                                      if (!_canToggleCategory(catId, value))
                                        return;

                                      setState(() {
                                        if (value) {
                                          selectedCategoryIds.add(catId);
                                        } else {
                                          selectedCategoryIds.remove(catId);
                                          for (final t in typesOfCat) {
                                            selectedServiceTypeIds
                                                .remove(t['id'] as String);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: typesOfCat.map((t) {
                                  final id = t['id'] as String;
                                  final selected =
                                      selectedServiceTypeIds.contains(id);

                                  return ChoiceChip(
                                    label: Text(
                                      t['name'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: selected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    selected: selected,
                                    selectedColor: primary,
                                    backgroundColor: Colors.grey.shade200,
                                    onSelected: (value) {
                                      if (value) {
                                        if (!_canToggleServiceType(t, true))
                                          return;

                                        final already =
                                            selectedCategoryIds.contains(catId);
                                        if (!already) {
                                          if (!_canToggleCategory(catId, true))
                                            return;
                                          selectedCategoryIds.add(catId);
                                        }

                                        setState(() =>
                                            selectedServiceTypeIds.add(id));
                                      } else {
                                        setState(() {
                                          selectedServiceTypeIds.remove(id);

                                          final stillAny = typesOfCat.any(
                                            (other) =>
                                                selectedServiceTypeIds.contains(
                                                    other['id'] as String),
                                          );
                                          if (!stillAny)
                                            selectedCategoryIds.remove(catId);
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              if (selectedTypesOfCat.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Selecionados: ${selectedTypesOfCat.map((t) => t['name']).join(', ')}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saveAndGoToHome,
                        child: const Text('Salvar e continuar'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
