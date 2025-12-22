// lib/screens/client_account_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'role_selection_page.dart';
import 'client_signUp_step2_page.dart'; // <- tela de endereço já usada no cadastro

const _kRoxo = Color(0xFF3B246B);
const _kLaranja = Color(0xFFFF6600);

final _supabase = Supabase.instance.client;
final _imagePicker = ImagePicker();

/// ======================
///  MINHA CONTA (CLIENTE)
/// ======================

class ClientAccountPage extends StatefulWidget {
  const ClientAccountPage({super.key});

  @override
  State<ClientAccountPage> createState() => _ClientAccountPageState();
}

class _ClientAccountPageState extends State<ClientAccountPage> {
  bool _loadingProfile = true;

  String? _emailAuth;
  String? _name;
  String? _city;
  String? _stateUf;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);

    try {
      final user = _supabase.auth.currentUser;
      _emailAuth = user?.email;

      if (user == null) {
        setState(() => _loadingProfile = false);
        return;
      }

      // clients.id == auth.user.id
      final res = await _supabase
          .from('clients')
          .select('full_name, city, address_state, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _name = res?['full_name'] as String?;
        _city = res?['city'] as String?;
        _stateUf = res?['address_state'] as String?;
        _avatarUrl = res?['avatar_url'] as String?;
        _loadingProfile = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar perfil do cliente: $e');
      if (!mounted) return;
      setState(() => _loadingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  String _formatLocation() {
    if ((_city ?? '').isEmpty) return 'Cidade não informada';
    if ((_stateUf ?? '').isEmpty) return _city!;
    return '$_city - $_stateUf';
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RoleSelectionPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e')),
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final storagePath = '${user.id}/$fileName';

      // bucket: client-avatars
      await _supabase.storage.from('client-avatars').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('client-avatars').getPublicUrl(storagePath);

      await _supabase
          .from('clients')
          .update({'avatar_url': publicUrl}).eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _avatarUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada!')),
      );
    } catch (e) {
      debugPrint('Erro ao atualizar avatar: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar foto: $e')),
      );
    }
  }

  Future<void> _openProfileEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientProfileEditPage(),
      ),
    );
    _loadProfile();
  }

  void _shareInvite() {
    const link = 'https://www.renthus.com.br';
    const message =
        'Conheça o Renthus Service! Peça serviços com praticidade e segurança. Acesse: $link';
    Share.share(message);
  }

  void _openPartnerStores() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PartnerStoresPage(),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                color: _kRoxo,
              ),
              child: const Text(
                'Minha conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // CONTEÚDO
            Expanded(
              child: _loadingProfile
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
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
                                      backgroundColor: _kRoxo.withOpacity(0.1),
                                      backgroundImage: _avatarUrl != null &&
                                              _avatarUrl!.isNotEmpty
                                          ? NetworkImage(_avatarUrl!)
                                          : null,
                                      child: _avatarUrl == null ||
                                              _avatarUrl!.isEmpty
                                          ? const Icon(
                                              Icons.person,
                                              color: _kRoxo,
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
                                          color: _kRoxo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name?.isNotEmpty == true
                                          ? _name!
                                          : (_emailAuth ?? 'Cliente Renthus'),
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
                                    const SizedBox(height: 6),
                                    Text(
                                      _emailAuth ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // LOJAS PARCEIRAS
                        const Text(
                          'Benefícios e parcerias',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kRoxo,
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
                              color: _kRoxo,
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

                        // MEU PERFIL
                        const Text(
                          'Minha conta',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kRoxo,
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
                                  color: _kRoxo,
                                ),
                                title: const Text('Meu perfil'),
                                subtitle: const Text(
                                  'Edite seu email, telefone e endereço.',
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.black45,
                                ),
                                onTap: _openProfileEdit,
                              ),
                              const Divider(height: 0),
                              ListTile(
                                leading: const Icon(
                                  Icons.card_giftcard_outlined,
                                  color: _kLaranja,
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
                            color: _kRoxo,
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
                                  color: _kRoxo,
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
                              color: _kLaranja,
                            ),
                            title: const Text(
                              'Sair do app',
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Encerra a sessão neste dispositivo.',
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: _logout,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- MEU PERFIL (EDIÇÃO) --------------------

class ClientProfileEditPage extends StatefulWidget {
  const ClientProfileEditPage({super.key});

  @override
  State<ClientProfileEditPage> createState() => _ClientProfileEditPageState();
}

class _ClientProfileEditPageState extends State<ClientProfileEditPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;

  // Dados lidos da tabela clients + auth
  String? _fullName;
  String? _emailAuth;
  String? _phone;
  String? _cep;
  String? _street;
  String? _number;
  String? _district;
  String? _city;
  String? _state;

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
        setState(() => _loading = false);
        return;
      }

      _emailAuth = user.email;

      final res = await _supabase
          .from('clients')
          .select(
            '''
            full_name,
            phone,
            address_zip_code,
            address_street,
            address_number,
            address_district,
            city,
            address_state
          ''',
          )
          .eq('id', user.id) // id == auth.uid()
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _fullName = (res?['full_name'] as String?) ?? '';
        _phone = (res?['phone'] as String?) ?? '';
        _cep = (res?['address_zip_code'] as String?) ?? '';
        _street = (res?['address_street'] as String?) ?? '';
        _number = (res?['address_number'] as String?) ?? '';
        _district = (res?['address_district'] as String?) ?? '';
        _city = (res?['city'] as String?) ?? '';
        _state = (res?['address_state'] as String?) ?? '';
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados do perfil: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  // Abre tela de edição de email
  Future<void> _openEditEmail() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientEditEmailPage(
          currentEmail: _emailAuth ?? '',
        ),
      ),
    );

    // Se voltarmos com true, recarrega para refletir novo email
    if (result == true) {
      await _loadProfile();
    }
  }

  // Abre tela de alteração de telefone
  Future<void> _openEditPhone() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientChangePhonePage(
          currentPhone: _phone ?? '',
        ),
      ),
    );

    if (result == true) {
      await _loadProfile();
    }
  }

  // Abre tela de edição de endereço (cadastro já existente)
  Future<void> _openAddressEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientSignUpStep2Page(),
      ),
    );
    await _loadProfile();
  }

  Future<void> _confirmDeleteAccount() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir conta?'),
          content: const Text(
            'Essa ação não poderá ser desfeita.\n\n'
            'Seu cadastro será removido, porém seus históricos de pedidos '
            'e interações serão mantidos por segurança.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // fechar o alerta
                await _deleteAccount();
              },
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Pequeno loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1) Mantém os históricos (não apagamos pedidos)

      // 2) Remove a linha da tabela clients
      await _supabase.from('clients').delete().eq('id', user.id);

      // 3) Remove o usuário do auth
      await _supabase.auth.admin.deleteUser(user.id);

      if (!mounted) return;

      Navigator.pop(context); // fechar loading

      // 4) volta para tela inicial
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (_) => false,
      );
    } catch (e) {
      Navigator.pop(context); // fechar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir conta: $e')),
      );
    }
  }

  Widget _buildValueLine(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildEditChip(VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit, size: 14, color: Colors.blue),
            SizedBox(width: 4),
            Text(
              'Editar',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =================== DADOS PESSOAIS ===================
                    const Text(
                      'Dados pessoais',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kRoxo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildValueLine('Nome completo', _fullName ?? ''),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              _buildEditChip(_openEditEmail),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _emailAuth ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Telefone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              _buildEditChip(_openEditPhone),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _phone?.isNotEmpty == true
                                ? _phone!
                                : 'Não informado',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Em breve, ao alterar o telefone, você poderá precisar confirmar com um código por SMS.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =================== ENDEREÇO ===================
                    const Text(
                      'Endereço',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kRoxo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'CEP',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: _openAddressEdit,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Text(
                                    'Editar com CEP',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cep?.isNotEmpty == true ? _cep! : 'Não informado',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildValueLine('Rua', _street ?? ''),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _buildValueLine(
                                  'Número',
                                  _number ?? '',
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildValueLine(
                                  'Bairro',
                                  _district ?? '',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildValueLine('Cidade', _city ?? ''),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildValueLine('UF', _state ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    // =================== EXCLUIR CONTA ===================
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmDeleteAccount,
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Excluir conta',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

/// =================== EDITAR EMAIL ===================

class ClientEditEmailPage extends StatefulWidget {
  final String currentEmail;

  const ClientEditEmailPage({
    super.key,
    required this.currentEmail,
  });

  @override
  State<ClientEditEmailPage> createState() => _ClientEditEmailPageState();
}

class _ClientEditEmailPageState extends State<ClientEditEmailPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final newEmail = _emailController.text.trim();

    if (newEmail == user.email) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _saving = true);

    try {
      // Atualiza email no auth
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      // Atualiza email na tabela clients (se houver coluna)
      await _supabase
          .from('clients')
          .update({'email': newEmail}).eq('id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email atualizado com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao atualizar email: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar email: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar email'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      const Text(
                        'Novo email',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'seuemail@exemplo.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe um email';
                          }
                          if (!v.contains('@')) {
                            return 'Email inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Você poderá precisar confirmar esse email através de um link enviado pela plataforma.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRoxo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar email'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =================== ALTERAR TELEFONE ===================
///
/// Aqui deixamos pronto para, no futuro, chamar a tela de verificação
/// por SMS (client_phone_verification_page). Por enquanto, apenas
/// atualiza o campo phone na tabela clients.
class ClientChangePhonePage extends StatefulWidget {
  final String currentPhone;

  const ClientChangePhonePage({
    super.key,
    required this.currentPhone,
  });

  @override
  State<ClientChangePhonePage> createState() => _ClientChangePhonePageState();
}

class _ClientChangePhonePageState extends State<ClientChangePhonePage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentPhone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final newPhone = _phoneController.text.trim();

    setState(() => _saving = true);

    try {
      // Se quiser usar a tela client_phone_verification_page,
      // você pode navegar para ela aqui antes de realmente salvar
      // na tabela clients.

      await _supabase
          .from('clients')
          .update({'phone': newPhone}).eq('id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefone atualizado com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao atualizar telefone: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar telefone: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar telefone'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      const Text(
                        'Novo telefone',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'DDD + número',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe um telefone';
                          }
                          if (v.trim().length < 8) {
                            return 'Telefone muito curto';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Em breve, ao alterar o telefone, você poderá precisar confirmar com um código por SMS.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRoxo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar telefone'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------- LOJAS PARCEIRAS --------------------

class PartnerStoresPage extends StatefulWidget {
  const PartnerStoresPage({super.key});

  @override
  State<PartnerStoresPage> createState() => _PartnerStoresPageState();
}

class _PartnerStoresPageState extends State<PartnerStoresPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
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
      final res = await _supabase
          .from('partner_stores')
          .select(
            '''
            id,
            name,
            short_description,
            address,
            city,
            state,
            cover_image_url
          ''',
          )
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;

      _stores = List<Map<String, dynamic>>.from(res as List<dynamic>);
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Erro ao carregar lojas parceiras: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar lojas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lojas parceiras'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF2F2F2),
      body: RefreshIndicator(
        onRefresh: _loadStores,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stores.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: const Text(
                        'Em breve você verá aqui lojas e parceiros '
                        'com vantagens especiais para clientes Renthus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      final name = store['name'] as String? ?? 'Loja parceira';
                      final desc = store['short_description'] as String? ?? '';
                      final address = store['address'] as String? ?? '';
                      final city = store['city'] as String? ?? '';
                      final state = store['state'] as String? ?? '';
                      final cover = store['cover_image_url'] as String?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cover != null && cover.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18),
                                ),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.network(
                                    cover,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _kRoxo,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (desc.isNotEmpty)
                                    Text(
                                      desc,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: _kLaranja,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          [
                                            address,
                                            if (city.isNotEmpty) city,
                                            if (state.isNotEmpty) state,
                                          ]
                                              .where((e) => e.isNotEmpty)
                                              .join(' • '),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Placeholder da Central de ajuda (fluxo pra criar depois)
class HelpCenterPlaceholderPage extends StatelessWidget {
  const HelpCenterPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de ajuda'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: const Text(
            'Em breve você poderá falar com o suporte Renthus direto por aqui. 🙂',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
