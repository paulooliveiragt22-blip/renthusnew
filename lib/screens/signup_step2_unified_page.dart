import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/onboarding_repository.dart';
import 'signup_step1_page.dart'; // SignupRole
import 'app_gate_page.dart';

class SignupStep2UnifiedPage extends StatefulWidget {
  final SignupRole? initialRole; // vindo da ConfirmEmail (role pré-selecionada)

  const SignupStep2UnifiedPage({super.key, this.initialRole});

  @override
  State<SignupStep2UnifiedPage> createState() => _SignupStep2UnifiedPageState();
}

class _SignupStep2UnifiedPageState extends State<SignupStep2UnifiedPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _onboardingRepo = OnboardingRepository();

  SignupRole? selectedRole;

  // dados do Step1 (user_metadata)
  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // ------- CLIENT (endereço)
  final cCep = TextEditingController();
  final cStreet = TextEditingController();
  final cNumber = TextEditingController();
  final cDistrict = TextEditingController();
  final cCity = TextEditingController();
  final cState = TextEditingController();

  bool cLoadingCep = false;
  bool cSaving = false;

  // ------- PROVIDER (tabs)
  late final TabController tabCtrl;

  final pCep = TextEditingController();
  final pStreet = TextEditingController();
  final pNumber = TextEditingController();
  final pComplement = TextEditingController();
  final pDistrict = TextEditingController();
  final pCity = TextEditingController();
  final pState = TextEditingController();

  bool pLoadingCep = false;
  bool pSaving = false;

  // serviços provider
  bool servicesLoading = false;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> serviceTypes = [];
  final Set<String> selectedCategoryIds = {};
  final Set<String> selectedServiceTypeIds = {};

  @override
  void initState() {
    super.initState();
    selectedRole = widget.initialRole;

    tabCtrl = TabController(length: 2, vsync: this);
    tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    // Onboarding (fail-safe): usuário chegou no Step2
    _onboardingRepo.upsert(status: 'step2_started');

    _loadStep1Data();
  }

  @override
  void dispose() {
    fullNameCtrl.dispose();
    phoneCtrl.dispose();

    cCep.dispose();
    cStreet.dispose();
    cNumber.dispose();
    cDistrict.dispose();
    cCity.dispose();
    cState.dispose();

    pCep.dispose();
    pStreet.dispose();
    pNumber.dispose();
    pComplement.dispose();
    pDistrict.dispose();
    pCity.dispose();
    pState.dispose();

    tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStep1Data() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final meta = user.userMetadata ?? {};
    fullNameCtrl.text = (meta['full_name'] ?? '').toString();
    phoneCtrl.text = (meta['phone'] ?? '').toString();

    // Se não veio role no constructor, tenta inferir do intended_role do metadata
    if (selectedRole == null) {
      final intended = (meta['intended_role'] ?? '').toString();
      if (intended == 'client') selectedRole = SignupRole.client;
      if (intended == 'provider') selectedRole = SignupRole.provider;
    }

    if (!mounted) return;
    setState(() {});

    if (selectedRole == SignupRole.provider) {
      _loadProviderServices();
    }
  }

  // ---------------- UI topo (toggle)
  void _selectRole(SignupRole role) {
    setState(() => selectedRole = role);
    if (role == SignupRole.provider) _loadProviderServices();
  }

  // ---------------- ViaCEP
  Future<Map<String, String>?> _fetchCep(String raw) async {
    final cep = raw.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return null;

    final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body);
    if (data is Map && data['erro'] == true) return null;

    return {
      'street': (data['logradouro'] ?? '').toString(),
      'district': (data['bairro'] ?? '').toString(),
      'city': (data['localidade'] ?? '').toString(),
      'state': (data['uf'] ?? '').toString(),
    };
  }

  Future<void> _buscarCepClient() async {
    if (cLoadingCep) return;
    setState(() => cLoadingCep = true);
    try {
      final d = await _fetchCep(cCep.text);
      if (d == null) throw Exception('CEP não encontrado.');
      cStreet.text = d['street']!;
      cDistrict.text = d['district']!;
      cCity.text = d['city']!;
      cState.text = d['state']!;
    } catch (e) {
      _snack('Erro ao buscar CEP: $e');
    } finally {
      if (mounted) setState(() => cLoadingCep = false);
    }
  }

  Future<void> _buscarCepProvider() async {
    if (pLoadingCep) return;
    setState(() => pLoadingCep = true);
    try {
      final d = await _fetchCep(pCep.text);
      if (d == null) throw Exception('CEP não encontrado.');
      pStreet.text = d['street']!;
      pDistrict.text = d['district']!;
      pCity.text = d['city']!;
      pState.text = d['state']!;
    } catch (e) {
      _snack('Erro ao buscar CEP: $e');
    } finally {
      if (mounted) setState(() => pLoadingCep = false);
    }
  }

  // ---------------- Provider services load
  Future<void> _loadProviderServices() async {
    if (servicesLoading) return;

    setState(() => servicesLoading = true);

    try {
      final catsRes = await supabase
          .from('v_service_categories_public')
          .select('id, name, icon, sort_order')
          .order('sort_order');

      final typesRes = await supabase
          .from('v_service_types_public')
          .select('id, name, category_id, sort_order')
          .order('sort_order');

      // Pode retornar vazio se ainda não houver provider — ok
      final selectedRes = await supabase
          .from('v_provider_service_types_me')
          .select('service_type_id');

      final selectedIds = <String>{
        for (final row in (selectedRes as List<dynamic>))
          if (row['service_type_id'] != null) row['service_type_id'].toString(),
      };

      final typeList = List<Map<String, dynamic>>.from(typesRes as List);
      final catList = List<Map<String, dynamic>>.from(catsRes as List);

      final catIdsFromSelected = <String>{
        for (final t in typeList)
          if (selectedIds.contains(t['id'].toString()))
            t['category_id'].toString(),
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

        servicesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => servicesLoading = false);
      _snack('Erro ao carregar serviços: $e');
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

  // ---------------- Finalizar CLIENT
  Future<void> _finishClient() async {
    if (cSaving) return;

    if (selectedRole != SignupRole.client) {
      _snack('Selecione uma opção no topo para continuar.');
      return;
    }

    if (fullNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      _snack('Informe seu nome e telefone.');
      return;
    }

    final cep = cCep.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      _snack('Informe um CEP válido.');
      return;
    }

    if (cStreet.text.trim().isEmpty ||
        cNumber.text.trim().isEmpty ||
        cDistrict.text.trim().isEmpty ||
        cCity.text.trim().isEmpty ||
        cState.text.trim().isEmpty) {
      _snack('Preencha o endereço completo.');
      return;
    }

    setState(() => cSaving = true);
    try {
      await supabase.rpc('rpc_client_step2', params: {
        'p_full_name': fullNameCtrl.text.trim(),
        'p_phone': phoneCtrl.text.trim(),
        'p_city': cCity.text.trim(),
        'p_address_zip_code': cCep.text.trim(),
        'p_address_street': cStreet.text.trim(),
        'p_address_number': cNumber.text.trim(),
        'p_address_district': cDistrict.text.trim(),
        'p_address_state': cState.text.trim(),
      });

      // Onboarding (fail-safe): cadastro concluído
      await _onboardingRepo.upsert(status: 'completed');

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (_) => false,
      );
    } on PostgrestException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Erro ao finalizar cadastro: $e');
    } finally {
      if (mounted) setState(() => cSaving = false);
    }
  }

  bool _providerAddressLooksValid() {
    final cep = pCep.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return false;

    if (pStreet.text.trim().isEmpty ||
        pNumber.text.trim().isEmpty ||
        pDistrict.text.trim().isEmpty ||
        pCity.text.trim().isEmpty ||
        pState.text.trim().isEmpty) {
      return false;
    }

    if (fullNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      return false;
    }

    return true;
  }

  void _goToServicesTab() {
    // Se endereço não estiver preenchido, mantém o fluxo mais claro pro usuário
    if (!_providerAddressLooksValid()) {
      _snack('Preencha o endereço completo para continuar.');
      return;
    }
    tabCtrl.animateTo(1);
  }

  // ---------------- Finalizar PROVIDER
  Future<void> _finishProvider() async {
    if (pSaving) return;

    if (selectedRole != SignupRole.provider) {
      _snack('Selecione uma opção no topo para continuar.');
      return;
    }

    if (fullNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      _snack('Informe seu nome e telefone.');
      return;
    }

    final cep = pCep.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      _snack('Informe um CEP válido.');
      return;
    }

    if (pStreet.text.trim().isEmpty ||
        pNumber.text.trim().isEmpty ||
        pDistrict.text.trim().isEmpty ||
        pCity.text.trim().isEmpty ||
        pState.text.trim().isEmpty) {
      _snack('Preencha o endereço completo.');
      return;
    }

    if (selectedServiceTypeIds.isEmpty) {
      _snack('Selecione pelo menos um serviço.');
      return;
    }

    setState(() => pSaving = true);
    try {
      await supabase.rpc('rpc_provider_set_services', params: {
        'p_full_name': fullNameCtrl.text.trim(),
        'p_phone': phoneCtrl.text.trim(),
        'p_city': pCity.text.trim(),
        'p_cep': pCep.text.trim(),
        'p_address_street': pStreet.text.trim(),
        'p_address_number': pNumber.text.trim(),
        'p_address_complement':
            pComplement.text.trim().isEmpty ? null : pComplement.text.trim(),
        'p_address_district': pDistrict.text.trim(),
        'p_state': pState.text.trim(),
        'p_service_type_ids': selectedServiceTypeIds.toList(),
      });

      // Onboarding (fail-safe): cadastro concluído
      await _onboardingRepo.upsert(status: 'completed');

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (_) => false,
      );
    } on PostgrestException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Erro ao finalizar cadastro: $e');
    } finally {
      if (mounted) setState(() => pSaving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _topRoleToggle() {
    const roxo = Color(0xFF3B246B);
    const laranja = Color(0xFFFF6600);

    final isClient = selectedRole == SignupRole.client;
    final isProvider = selectedRole == SignupRole.provider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Quero contratar serviços'),
                selected: isClient,
                onSelected: (_) => _selectRole(SignupRole.client),
                selectedColor: roxo,
                labelStyle: TextStyle(
                  color: isClient ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text('Quero prestar serviços'),
                selected: isProvider,
                onSelected: (_) => _selectRole(SignupRole.provider),
                selectedColor: laranja,
                labelStyle: TextStyle(
                  color: isProvider ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Selecione uma opção acima para concluir o cadastro.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Concluir cadastro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topRoleToggle(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Sempre exibir campos e pré-preencher com user_metadata
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone / WhatsApp',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),

                // Se não selecionou, não mostra formulário e não permite finalizar
                if (selectedRole == SignupRole.client) _clientForm(),
                if (selectedRole == SignupRole.provider) _providerForm(),

                if (selectedRole == null) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Escolha se você quer contratar ou prestar serviços para ver o formulário.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientForm() {
    const roxo = Color(0xFF3B246B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Endereço (Cliente)',
          style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: roxo),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: cCep,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CEP',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final d = v.replaceAll(RegExp(r'\D'), '');
                  if (d.length == 8) _buscarCepClient();
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: cLoadingCep ? null : _buscarCepClient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: roxo,
                  foregroundColor: Colors.white,
                ),
                child: cLoadingCep
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Buscar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cStreet,
          decoration: const InputDecoration(
            labelText: 'Rua / Avenida',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cNumber,
          decoration: const InputDecoration(
            labelText: 'Número',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cDistrict,
          decoration: const InputDecoration(
            labelText: 'Bairro',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cCity,
          decoration: const InputDecoration(
            labelText: 'Cidade',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cState,
          decoration: const InputDecoration(
            labelText: 'Estado (UF)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: cSaving ? null : _finishClient,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0DAA00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: cSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Finalizar cadastro (Cliente)'),
        ),
      ],
    );
  }

  Widget _providerForm() {
    const roxo = Color(0xFF3B246B);

    final bool isOnAddressTab = tabCtrl.index == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Configuração (Prestador)',
          style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: roxo),
        ),
        const SizedBox(height: 10),
        TabBar(
          controller: tabCtrl,
          labelColor: roxo,
          tabs: const [
            Tab(text: 'Endereço'),
            Tab(text: 'Selecionar serviços'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 620,
          child: TabBarView(
            controller: tabCtrl,
            children: [
              _providerAddressTab(),
              _providerServicesTab(),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ✅ Botão único: no endereço vira "Continuar" (vai pra aba serviços)
        // e na aba de serviços vira "Finalizar cadastro (Prestador)"
        ElevatedButton(
          onPressed: pSaving
              ? null
              : isOnAddressTab
                  ? _goToServicesTab
                  : _finishProvider,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0DAA00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: pSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isOnAddressTab
                  ? 'Continuar'
                  : 'Finalizar cadastro (Prestador)'),
        ),
      ],
    );
  }

  Widget _providerAddressTab() {
    const roxo = Color(0xFF3B246B);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: pCep,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CEP',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final d = v.replaceAll(RegExp(r'\D'), '');
                    if (d.length == 8) _buscarCepProvider();
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: pLoadingCep ? null : _buscarCepProvider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: roxo,
                    foregroundColor: Colors.white,
                  ),
                  child: pLoadingCep
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Buscar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pStreet,
            decoration: const InputDecoration(
              labelText: 'Rua / Logradouro',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pNumber,
            decoration: const InputDecoration(
              labelText: 'Número',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pComplement,
            decoration: const InputDecoration(
              labelText: 'Complemento (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pDistrict,
            decoration: const InputDecoration(
              labelText: 'Bairro',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pCity,
            decoration: const InputDecoration(
              labelText: 'Cidade',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pState,
            decoration: const InputDecoration(
              labelText: 'UF',
              border: OutlineInputBorder(),
            ),
          ),

          // ✅ Mensagem humanizada abaixo do último campo
          const SizedBox(height: 10),
          const Text(
            'Perfeito! Só falta mais um passo 😊\n'
            'Clique em “Continuar” para selecionar os serviços que você vai prestar no app.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _providerServicesTab() {
    if (servicesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    const primary = Color(0xFF3B246B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ✅ Texto informativo no topo da aba de serviços
        const Padding(
          padding: EdgeInsets.only(top: 6, bottom: 10),
          child: Text(
            'Agora escolha os serviços que você quer oferecer.\n'
            'Essas opções vão aparecer para os clientes quando eles estiverem buscando um prestador.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final catId = cat['id'].toString();

              final typesOfCat = serviceTypes
                  .where((t) => t['category_id'].toString() == catId)
                  .toList();
              if (typesOfCat.isEmpty) return const SizedBox.shrink();

              final selectedTypesOfCat = typesOfCat
                  .where((t) =>
                      selectedServiceTypeIds.contains(t['id'].toString()))
                  .toList();

              final bool catExplicitSelected =
                  selectedCategoryIds.contains(catId);
              final bool catHasSelectedTypes = selectedTypesOfCat.isNotEmpty;
              final bool catEffectiveSelected =
                  catExplicitSelected || catHasSelectedTypes;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _mapCategoryIcon((cat['icon'] ?? '').toString()),
                            color: primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (cat['name'] ?? '').toString(),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Switch(
                            value: catEffectiveSelected,
                            activeColor: primary,
                            onChanged: (value) {
                              setState(() {
                                if (value) {
                                  selectedCategoryIds.add(catId);
                                } else {
                                  selectedCategoryIds.remove(catId);
                                  for (final t in typesOfCat) {
                                    selectedServiceTypeIds
                                        .remove(t['id'].toString());
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
                          final id = t['id'].toString();
                          final selected = selectedServiceTypeIds.contains(id);

                          return ChoiceChip(
                            label: Text(
                              (t['name'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: selected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: selected,
                            selectedColor: primary,
                            backgroundColor: Colors.grey.shade200,
                            onSelected: (value) {
                              if (value) {
                                setState(() {
                                  selectedServiceTypeIds.add(id);
                                  selectedCategoryIds.add(catId);
                                });
                              } else {
                                setState(() {
                                  selectedServiceTypeIds.remove(id);

                                  final stillAny = typesOfCat.any(
                                    (other) => selectedServiceTypeIds
                                        .contains(other['id'].toString()),
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
                          'Selecionados: ${selectedTypesOfCat.map((t) => (t['name'] ?? '').toString()).join(', ')}',
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
      ],
    );
  }
}
