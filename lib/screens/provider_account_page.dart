import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'role_selection_page.dart';
import 'partner_stores_page.dart';
import 'provider_address_step3_page.dart';
import 'provider_service_selection_screen.dart';
import 'provider_phone_verification_page.dart';

const kRoxo = Color(0xFF3B246B);
const kLaranja = Color(0xFFFF6600);

final _supabase = Supabase.instance.client;

/// =======================
/// MINHA CONTA (PRESTADOR)
/// =======================
class ProviderAccountPage extends StatefulWidget {
  const ProviderAccountPage({super.key});

  @override
  State<ProviderAccountPage> createState() => _ProviderAccountPageState();
}

class _ProviderAccountPageState extends State<ProviderAccountPage> {
  bool _loadingProfile = true;

  // Tudo vem de v_provider_me
  String? _providerId;
  String? _fullName;
  String? _city;
  String? _stateUf;
  String? _phone;
  String? _emailAuth;
  String? _avatarUrl;

  String? _cep;
  String? _street;
  String? _number;
  String? _district;

  bool _uploadingAvatar = false;

  bool _loadingServices = true;
  List<_ProviderCategoryItem> _serviceItems = [];

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    await Future.wait<void>([
      _loadProfileFromView(),
      _loadMyServicesFromView(),
    ]);
  }

  Future<void> _loadProfileFromView() async {
    setState(() => _loadingProfile = true);

    try {
      final user = _supabase.auth.currentUser;
      _emailAuth = user?.email;

      if (user == null) {
        if (!mounted) return;
        setState(() => _loadingProfile = false);
        return;
      }

      // ✅ SOMENTE VIEW
      final me = await _supabase.from('v_provider_me').select().maybeSingle();

      if (!mounted) return;

      if (me == null) {
        setState(() {
          _loadingProfile = false;
          _providerId = null;
          _fullName = null;
          _phone = null;
          _city = null;
          _stateUf = null;
          _avatarUrl = null;
          _cep = null;
          _street = null;
          _number = null;
          _district = null;
        });
        return;
      }

      final m = Map<String, dynamic>.from(me as Map);

      setState(() {
        _providerId = m['provider_id']?.toString();

        _fullName = (m['full_name'] as String?)?.trim();
        _phone = (m['phone'] as String?)?.trim();
        _city = (m['city'] as String?)?.trim();
        _stateUf = (m['state'] as String?)?.trim();
        _avatarUrl = (m['avatar_url'] as String?)?.trim();

        _cep = (m['cep'] as String?)?.trim();
        _street = (m['address_street'] as String?)?.trim();
        _number = (m['address_number'] as String?)?.trim();
        _district = (m['address_district'] as String?)?.trim();

        _loadingProfile = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar v_provider_me: $e');
      if (!mounted) return;
      setState(() => _loadingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  String _formatLocation() {
    final c = _city ?? '';
    final s = _stateUf ?? '';
    if (c.isEmpty && s.isEmpty) return 'Cidade não informada';
    if (c.isNotEmpty && s.isEmpty) return c;
    if (c.isEmpty && s.isNotEmpty) return s;
    return '$c - $s';
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _uploadingAvatar) return;

    try {
      setState(() => _uploadingAvatar = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final ext = file.extension ?? 'jpg';
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('provider_avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('provider_avatars').getPublicUrl(fileName);

      // ✅ Atualiza via RPC (para não depender de tabela crua)
      // Crie essa RPC no banco depois: rpc_provider_update_avatar(p_avatar_url text)
      await _supabase.rpc('rpc_provider_update_avatar', params: {
        'p_avatar_url': publicUrl,
      });

      if (!mounted) return;
      setState(() {
        _avatarUrl = publicUrl;
        _uploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto atualizada com sucesso!')),
      );
    } catch (e) {
      debugPrint('Erro ao enviar foto do provider: $e');
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar foto: $e')),
      );
    }
  }

  void _openPartnerStores() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PartnerStoresPage(),
      ),
    );
  }

  void _shareInvite() {
    const link = 'https://www.renthus.com.br';
    const message =
        'Conheça o Renthus Service! Acesse e receba novos serviços na sua região: $link';
    Share.share(message);
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
      (route) => false,
    );
  }

  void _openHelpCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HelpCenterPlaceholderPage(),
      ),
    );
  }

  void _openTerms() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tela de Termos de uso ainda não implementada.'),
      ),
    );
  }

  void _openPrivacy() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Tela de Política de privacidade ainda não implementada.'),
      ),
    );
  }

  void _openProfileReadOnly() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderProfilePage(),
      ),
    );
    _loadProfileFromView();
  }

  void _openAddressEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderAddressStep3Page(),
      ),
    );
    _loadProfileFromView();
  }

  void _openServiceSelection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderServiceSelectionScreen(),
      ),
    );
    _loadMyServicesFromView();
  }

  /// ✅ Carrega serviços pela view v_public_provider_services
  Future<void> _loadMyServicesFromView() async {
    setState(() => _loadingServices = true);

    try {
      // precisa do provider_id (vem da v_provider_me)
      final me = await _supabase
          .from('v_provider_me')
          .select('provider_id')
          .maybeSingle();
      final providerId = _providerId; // já veio do _loadProfileFromView()

      if (providerId == null) {
        if (!mounted) return;
        setState(() {
          _serviceItems = [];
          _loadingServices = false;
        });
        return;
      }

      final rows = await _supabase
          .from('v_public_provider_services')
          .select('provider_id, service_type_name')
          .eq('provider_id', providerId);

      final items = <_ProviderCategoryItem>[];

      for (final r in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(r as Map);
        final name = (m['service_type_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;

        // Como sua view atual não traz categoria, mostramos como “Serviço”
        items.add(
            _ProviderCategoryItem(categoryName: 'Serviço', serviceName: name));
      }

      items.sort((a, b) => a.serviceName.compareTo(b.serviceName));

      if (!mounted) return;
      setState(() {
        _serviceItems = items;
        _loadingServices = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar v_public_provider_services: $e');
      if (!mounted) return;
      setState(() => _loadingServices = false);
    }
  }

  Future<void> _cancelAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar conta'),
        content: const Text(
          'Tem certeza que deseja cancelar sua conta de prestador?\n\n'
          'Seu cadastro será removido, mas os registros de serviços '
          'já realizados serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancelar conta'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // ✅ Deleta via RPC (pra não depender de tabela crua)
      // Crie depois: rpc_provider_delete_account()
      await _supabase.rpc('rpc_provider_delete_account');

      await _supabase.auth.signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Erro ao cancelar conta provider (RPC): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar conta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(color: kRoxo),
              child: const Text(
                'Minha conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: _loadingProfile
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadEverything,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // CARD PERFIL
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: _pickAndUploadAvatar,
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: kRoxo.withOpacity(0.1),
                                        backgroundImage: _avatarUrl != null &&
                                                _avatarUrl!.isNotEmpty
                                            ? NetworkImage(_avatarUrl!)
                                            : null,
                                        child: _avatarUrl == null ||
                                                _avatarUrl!.isEmpty
                                            ? const Icon(
                                                Icons.person,
                                                color: kRoxo,
                                                size: 30,
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: kRoxo,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fullName?.isNotEmpty == true
                                            ? _fullName!
                                            : (_emailAuth ??
                                                'Prestador Renthus'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatLocation(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (_phone?.isNotEmpty == true) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _phone!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      if (_emailAuth != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _emailAuth!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // BENEFÍCIOS
                          const Text(
                            'Benefícios e parcerias',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kRoxo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: const Icon(
                                Icons.store_mall_directory_outlined,
                                color: kRoxo,
                              ),
                              title: const Text('Lojas parceiras'),
                              subtitle: const Text(
                                'Ofertas especiais e serviços próximos de você.',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.black45,
                              ),
                              onTap: _openPartnerStores,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // MEUS SERVIÇOS
                          const Text(
                            'Minhas categorias e serviços',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kRoxo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.build_circle_outlined,
                                        color: kRoxo,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Serviços atendidos',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _openServiceSelection,
                                        child: const Text('Editar'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_loadingServices)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.0),
                                      child: Center(
                                        child: SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  else if (_serviceItems.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.only(top: 4, bottom: 6),
                                      child: Text(
                                        'Você ainda não selecionou serviços. Toque em "Editar" para configurar.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      ),
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _serviceItems
                                          .map(
                                            (item) => Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.check_circle,
                                                      size: 14, color: kRoxo),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      item.serviceName,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // MINHA CONTA
                          const Text(
                            'Minha conta',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kRoxo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.person_outline,
                                    color: kRoxo,
                                  ),
                                  title: const Text('Meu perfil'),
                                  subtitle: const Text(
                                    'Veja seus dados pessoais e endereço.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black45,
                                  ),
                                  onTap: _openProfileReadOnly,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                    Icons.card_giftcard_outlined,
                                    color: kLaranja,
                                  ),
                                  title: const Text('Indique e ganhe'),
                                  subtitle: const Text(
                                    'Compartilhe o Renthus com seus amigos.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black45,
                                  ),
                                  onTap: _shareInvite,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // AJUDA
                          const Text(
                            'Ajuda e suporte',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kRoxo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.headset_mic_outlined,
                                    color: kRoxo,
                                  ),
                                  title: const Text('Central de ajuda'),
                                  subtitle: const Text(
                                    'Fale com a equipe Renthus pelo app.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black45,
                                  ),
                                  onTap: _openHelpCenter,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                    Icons.description_outlined,
                                    color: Colors.black54,
                                  ),
                                  title: const Text('Termos de uso'),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black45,
                                  ),
                                  onTap: _openTerms,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                    Icons.privacy_tip_outlined,
                                    color: Colors.black54,
                                  ),
                                  title: const Text('Política de privacidade'),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black45,
                                  ),
                                  onTap: _openPrivacy,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // SAIR
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: const Icon(
                                Icons.logout,
                                color: kLaranja,
                              ),
                              title: const Text(
                                'Sair do app',
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: const Text(
                                'Encerra a sessão neste dispositivo.',
                                style: TextStyle(fontSize: 12),
                              ),
                              onTap: _signOut,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // CANCELAR CONTA
                          TextButton.icon(
                            onPressed: _cancelAccount,
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Cancelar minha conta'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCategoryItem {
  final String categoryName;
  final String serviceName;

  _ProviderCategoryItem({
    required this.categoryName,
    required this.serviceName,
  });
}

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

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // ✅ SOMENTE VIEW
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Fluxo de edição de email ainda não implementado.')),
    );
  }

  Future<void> _editPhone() async {
    final currentPhone = _phone ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderPhoneVerificationPage(phone: currentPhone),
      ),
    );
    _loadProfile();
  }

  Future<void> _editAddressWithCep() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderAddressStep3Page(),
      ),
    );
    _loadProfile();
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
                            'Em breve, ao alterar o telefone, você poderá precisar confirmar com um código por SMS.',
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
                              color: kRoxo),
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
                                      label: 'Número', value: _number ?? '')),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _LabelValue(
                                      label: 'Bairro', value: _district ?? '')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                  child: _LabelValue(
                                      label: 'Cidade', value: _city ?? '')),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _LabelValue(
                                      label: 'UF', value: _stateUf ?? '')),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit, size: 14, color: kRoxo),
            SizedBox(width: 4),
            Text(
              'Editar',
              style: TextStyle(
                fontSize: 11,
                color: kRoxo,
                fontWeight: FontWeight.w500,
              ),
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

class HelpCenterPlaceholderPage extends StatelessWidget {
  const HelpCenterPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de ajuda'),
        backgroundColor: kRoxo,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Em breve você poderá falar com o suporte Renthus direto por aqui. 🙂',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
