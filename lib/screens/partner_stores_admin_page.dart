import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class PartnerStoresAdminPage extends ConsumerStatefulWidget {
  const PartnerStoresAdminPage({super.key});

  @override
  ConsumerState<PartnerStoresAdminPage> createState() => _PartnerStoresAdminPageState();
}

class _PartnerStoresAdminPageState extends ConsumerState<PartnerStoresAdminPage> {

  bool _loading = true;
  List<Map<String, dynamic>> _stores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase
          .from('partner_stores')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _stores = List<Map<String, dynamic>>.from(res as List<dynamic>);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar lojas: $e')),
      );
    }
  }

  Future<void> _openStoreForm({Map<String, dynamic>? store}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartnerStoreFormSheet(
        store: store,
        onSaved: _loadStores,
        supabase: ref.read(supabaseProvider),
      ),
    );
  }

  Future<void> _deleteStore(Map<String, dynamic> store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover loja parceira'),
        content: Text(
          'Tem certeza que deseja remover "${store['name']}"?\n'
          'Os produtos vinculados também serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('partner_stores').delete().eq('id', store['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loja removida.')),
      );
      _loadStores();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover loja: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lojas Parceiras (Admin)'),
        backgroundColor: roxo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: roxo,
        icon: const Icon(Icons.add),
        label: const Text('Nova loja'),
        onPressed: () => _openStoreForm(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStores,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stores.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma loja cadastrada ainda.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stores.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      final isActive = store['is_active'] == true;

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openStoreForm(store: store),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: store['cover_image_url'] != null &&
                                          (store['cover_image_url'] as String)
                                              .isNotEmpty
                                      ? Image.network(
                                          store['cover_image_url'] as String,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.storefront,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              store['name'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? const Color(0xFF0DAA00)
                                                      .withOpacity(0.12)
                                                  : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              isActive ? 'Ativa' : 'Inativa',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isActive
                                                    ? const Color(0xFF0DAA00)
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (store['short_description'] != null &&
                                          (store['short_description'] as String)
                                              .isNotEmpty)
                                        Text(
                                          store['short_description'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              [store['city'], store['state']]
                                                  .where((e) =>
                                                      (e as String?)
                                                          ?.isNotEmpty ==
                                                      true,)
                                                  .join(' - '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            onPressed: () =>
                                                _deleteStore(store),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: Colors.redAccent,
                                            ),
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
                    },
                  ),
      ),
    );
  }
}

class _PartnerStoreFormSheet extends StatefulWidget {

  const _PartnerStoreFormSheet({
    required this.store,
    required this.onSaved,
    required this.supabase,
  });
  final Map<String, dynamic>? store;
  final VoidCallback onSaved;
  final SupabaseClient supabase;

  @override
  State<_PartnerStoreFormSheet> createState() => _PartnerStoreFormSheetState();
}

class _PartnerStoreFormSheetState extends State<_PartnerStoreFormSheet> {

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _shortDescCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _coverCtrl;
  late final TextEditingController _latitudeCtrl;
  late final TextEditingController _longitudeCtrl;

  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.store;

    _nameCtrl = TextEditingController(text: s?['name'] ?? '');
    _shortDescCtrl = TextEditingController(text: s?['short_description'] ?? '');
    _addressCtrl = TextEditingController(text: s?['address'] ?? '');
    _cityCtrl = TextEditingController(text: s?['city'] ?? '');
    _stateCtrl = TextEditingController(text: s?['state'] ?? '');
    _coverCtrl = TextEditingController(text: s?['cover_image_url'] ?? '');
    _latitudeCtrl =
        TextEditingController(text: s?['latitude']?.toString() ?? '');
    _longitudeCtrl =
        TextEditingController(text: s?['longitude']?.toString() ?? '');
    _isActive = (s?['is_active'] as bool?) ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortDescCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _coverCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'short_description': _shortDescCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'cover_image_url': _coverCtrl.text.trim(),
        'is_active': _isActive,
      };

      final lat = double.tryParse(_latitudeCtrl.text.trim());
      final lng = double.tryParse(_longitudeCtrl.text.trim());
      if (lat != null) data['latitude'] = lat;
      if (lng != null) data['longitude'] = lng;

      final supabase = widget.supabase;
      if (widget.store == null) {
        await supabase.from('partner_stores').insert(data);
      } else {
        await supabase
            .from('partner_stores')
            .update(data)
            .eq('id', widget.store!['id']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loja salva com sucesso.')),
      );
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar loja: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: mq.viewInsets.bottom + 12,
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.store == null
                    ? 'Nova loja parceira'
                    : 'Editar loja parceira',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roxo,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome da loja *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Informe o nome da loja';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _shortDescCtrl,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descrição curta',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Endereço',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cityCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Cidade',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _stateCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'UF',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _coverCtrl,
                          decoration: const InputDecoration(
                            labelText: 'URL da imagem de capa',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitudeCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: false,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _longitudeCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: false,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Loja ativa'),
                          subtitle: const Text(
                            'Ao desativar, ela deixa de aparecer para os clientes.',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: roxo,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Salvar loja',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
