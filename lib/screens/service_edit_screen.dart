// lib/screens/service_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class ServiceEditScreen extends ConsumerStatefulWidget {
  const ServiceEditScreen({super.key});

  @override
  ConsumerState<ServiceEditScreen> createState() => _ServiceEditScreenState();
}

class _ServiceEditScreenState extends ConsumerState<ServiceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _disputeHoursCtrl = TextEditingController();

  String? _categoryId;
  bool _loading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _originalService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Recupera argumentos (service) se vier em modo edição
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['service'] != null && !_isEditing) {
      _originalService = Map<String, dynamic>.from(args['service']);
      _isEditing = true;

      _nameCtrl.text = _originalService?['name']?.toString() ?? '';
      _descriptionCtrl.text = _originalService?['description']?.toString() ?? '';
      _priceCtrl.text = _originalService?['price']?.toString() ?? '';
      _unitCtrl.text = _originalService?['unit']?.toString() ?? '';
      _disputeHoursCtrl.text =
          _originalService?['dispute_hours']?.toString() ?? '';
      _categoryId = _originalService?['category_id']?.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _disputeHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final client = ref.read(supabaseProvider);
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado')),
        );
      }
      return;
    }

    setState(() => _loading = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'unit': _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      'dispute_hours':
          int.tryParse(_disputeHoursCtrl.text.trim()) ?? 0, // opcional
      'category_id': _categoryId,
      'provider_id': user.id, // se a coluna existir
    };

    try {
      if (_isEditing && _originalService != null) {
        final id = _originalService!['id'];
        await client.from('services_catalog').update(data).eq('id', id);
      } else {
        await client.from('services_catalog').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Serviço atualizado com sucesso'
                : 'Serviço criado com sucesso',),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar serviço: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar serviço' : 'Novo serviço';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do serviço',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Preço (ex: 150.00)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe um valor';
                        }
                        if (double.tryParse(v.replaceAll(',', '.')) == null) {
                          return 'Valor inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unidade (ex: diária, hora, serviço)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _disputeHoursCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Horas para disputa (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Categoria simples como texto/ID
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoria (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'cleaning', child: Text('Limpeza'),),
                        DropdownMenuItem(
                            value: 'construction', child: Text('Pedreiro'),),
                        DropdownMenuItem(
                            value: 'moving', child: Text('Fretes / mudanças'),),
                        DropdownMenuItem(
                            value: 'other', child: Text('Outros serviços'),),
                      ],
                      onChanged: (v) {
                        setState(() => _categoryId = v);
                      },
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: Text(_isEditing ? 'Salvar alterações' : 'Salvar'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black12,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
