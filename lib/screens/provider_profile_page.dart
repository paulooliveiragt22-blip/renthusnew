import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kRoxo = Color(0xFF3B246B);

final _supabase = Supabase.instance.client;

/// =======================
/// MEU PERFIL (PRESTADOR)
/// =======================
class ProviderProfilePage extends StatefulWidget {
  const ProviderProfilePage({super.key});

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  bool _loading = true;

  String? _fullName;
  String? _email;
  String? _phone;

  String? _cep;
  String? _street;
  String? _number;
  String? _district;
  String? _city;
  String? _stateUf;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _comingSoon([String msg = 'Em breve.']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final me = await _supabase.from('v_provider_me').select().maybeSingle();
      if (!mounted) return;

      _email = user.email ?? '';

      if (me == null) {
        setState(() => _loading = false);
        return;
      }

      final m = Map<String, dynamic>.from(me as Map);

      setState(() {
        _fullName = (m['full_name'] as String?) ?? '';
        _phone = (m['phone'] as String?) ?? '';

        _cep = (m['cep'] as String?) ?? '';
        _street = (m['address_street'] as String?) ?? '';
        _number = (m['address_number'] as String?) ?? '';
        _district = (m['address_district'] as String?) ?? '';
        _city = (m['city'] as String?) ?? '';
        _stateUf = (m['state'] as String?) ?? '';

        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar perfil (v_provider_me): $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  Future<void> _editEmail() async {
    _comingSoon('Fluxo de edição de email ainda não implementado.');
  }

  Future<void> _editPhone() async {
    _comingSoon('Edição de telefone será habilitada em breve.');
  }

  Future<void> _editAddressWithCep() async {
    _comingSoon('Edição de endereço será habilitada em breve.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        backgroundColor: kRoxo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    const Text(
                      'Dados pessoais',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kRoxo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nome completo',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(_fullName ?? '',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Email',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54)),
                                    const SizedBox(height: 4),
                                    Text(_email ?? '',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SmallEditChip(onTap: _editEmail),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Telefone',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54)),
                                    const SizedBox(height: 4),
                                    Text(_phone ?? '',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SmallEditChip(onTap: _editPhone),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Em breve, você poderá editar seus dados pessoais por aqui.',
                            style:
                                TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Endereço de atendimento',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kRoxo,
                          ),
                        ),
                        TextButton(
                          onPressed: _editAddressWithCep,
                          child: const Text('Editar com CEP'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LabelValue(label: 'CEP', value: _cep ?? ''),
                          const SizedBox(height: 8),
                          _LabelValue(label: 'Rua', value: _street ?? ''),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _LabelValue(
                                    label: 'Número', value: _number ?? ''),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LabelValue(
                                    label: 'Bairro', value: _district ?? ''),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _LabelValue(
                                    label: 'Cidade', value: _city ?? ''),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LabelValue(
                                    label: 'UF', value: _stateUf ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SmallEditChip extends StatelessWidget {
  final VoidCallback? onTap;

  const _SmallEditChip({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 14, color: kRoxo),
            SizedBox(width: 4),
            Text(
              'Editar',
              style: TextStyle(
                  fontSize: 11, color: kRoxo, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
