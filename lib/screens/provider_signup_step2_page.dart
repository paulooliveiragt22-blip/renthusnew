import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'provider_main_page.dart';

class ProviderSignupStep2Page extends StatefulWidget {
  const ProviderSignupStep2Page({super.key});

  @override
  State<ProviderSignupStep2Page> createState() =>
      _ProviderSignupStep2PageState();
}

class _ProviderSignupStep2PageState extends State<ProviderSignupStep2Page>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  late final TabController _tabController;

  // ---------------- FORM KEYS ----------------
  final _addressFormKey = GlobalKey<FormState>();

  // ---------------- ADDRESS ----------------
  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  // ---------------- SERVICES ----------------
  bool _loadingServices = true;
  final Set<String> _selectedServiceTypeIds = {};
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _serviceTypes = [];

  bool _loadingCep = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  // ---------------- LOAD SERVICES ----------------

  Future<void> _loadServices() async {
    try {
      final cats = await _supabase
          .from('v_service_categories_public')
          .select('id, name, icon, sort_order')
          .order('sort_order');

      final types = await _supabase
          .from('v_service_types_public')
          .select('id, name, category_id, sort_order')
          .order('sort_order');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(cats as List);
        _serviceTypes = List<Map<String, dynamic>>.from(types as List);
        _loadingServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar serviços: $e')),
      );
    }
  }

  // ---------------- CEP ----------------

  Future<void> _buscarCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;

    setState(() => _loadingCep = true);

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar CEP');
      }

      final data = json.decode(response.body);
      if (data['erro'] == true) {
        throw Exception('CEP não encontrado');
      }

      _streetController.text = data['logradouro'] ?? '';
      _districtController.text = data['bairro'] ?? '';
      _cityController.text = data['localidade'] ?? '';
      _stateController.text = data['uf'] ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar CEP: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  // ---------------- FINALIZAR ----------------

  Future<void> _finish() async {
    if (_saving) return;

    final addressForm = _addressFormKey.currentState;
    if (addressForm == null || !addressForm.validate()) {
      _tabController.animateTo(0);
      return;
    }

    if (_selectedServiceTypeIds.isEmpty) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um serviço.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _supabase.rpc(
        'rpc_provider_set_services',
        params: {
          'p_city': _cityController.text.trim(),
          'p_cep': _cepController.text.trim(),
          'p_address_street': _streetController.text.trim(),
          'p_address_number': _numberController.text.trim(),
          'p_address_complement': _complementController.text.trim().isEmpty
              ? null
              : _complementController.text.trim(),
          'p_address_district': _districtController.text.trim(),
          'p_state': _stateController.text.trim(),
          'p_service_type_ids': _selectedServiceTypeIds.toList(),
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProviderMainPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar cadastro: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro do Prestador'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Endereço'),
            Tab(text: 'Serviços'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildAddressTab(primary),
          _buildServicesTab(primary),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : () {
                      if (_tabController.index == 0) {
                        final ok =
                            _addressFormKey.currentState?.validate() ?? false;
                        if (ok) _tabController.animateTo(1);
                      } else {
                        _finish();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _tabController.index == 0
                          ? 'Continuar'
                          : 'Finalizar cadastro',
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TABS ----------------

  Widget _buildAddressTab(Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _addressFormKey,
        child: Column(
          children: [
            _field(_cepController, 'CEP', keyboard: TextInputType.number,
                onChanged: (v) {
              final d = v.replaceAll(RegExp(r'\D'), '');
              if (d.length == 8) _buscarCep();
            }),
            _field(_streetController, 'Rua / Avenida'),
            _field(_numberController, 'Número'),
            _field(_complementController, 'Complemento (opcional)',
                required: false),
            _field(_districtController, 'Bairro'),
            _field(_cityController, 'Cidade'),
            _field(_stateController, 'UF', maxLength: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesTab(Color primary) {
    if (_loadingServices) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _categories.map((cat) {
        final types =
            _serviceTypes.where((t) => t['category_id'] == cat['id']).toList();

        if (types.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat['name'],
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: types.map((t) {
                    final id = t['id'];
                    final selected = _selectedServiceTypeIds.contains(id);

                    return ChoiceChip(
                      label: Text(t['name']),
                      selected: selected,
                      selectedColor: primary,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedServiceTypeIds.add(id);
                          } else {
                            _selectedServiceTypeIds.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    bool required = true,
    int? maxLength,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null
            : null,
      ),
    );
  }
}
