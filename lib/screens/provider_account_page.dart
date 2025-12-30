import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'role_selection_page.dart';
import 'partner_stores_page.dart';

const kRoxo = Color(0xFF3B246B);
const kLaranja = Color(0xFFFF6600);

final _supabase = Supabase.instance.client;
final _imagePicker = ImagePicker();

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

  // role detectado via RPC
  String? _defaultRole; // client | provider | both | null

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

  void _comingSoon([String msg = 'Em breve.']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadRoles() async {
    try {
      final res = await _supabase.rpc('get_my_roles');
      if (res is List && res.isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        _defaultRole = row['default_role'] as String?;
      } else {
        _defaultRole = null;
      }
    } catch (e) {
      debugPrint('Erro ao carregar roles (get_my_roles): $e');
      _defaultRole = null;
    }
  }

  Future<String?> _selectRoleIfNeeded() async {
    if (_defaultRole == 'client' || _defaultRole == 'provider') {
      return _defaultRole;
    }

    if (_defaultRole == 'both') {
      if (!mounted) return null;
      return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Qual perfil deseja editar?'),
          content: const Text(
            'Você tem cadastro como cliente e como prestador. '
            'Qual avatar você quer alterar agora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'client'),
              child: const Text('Cliente'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'provider'),
              child: const Text('Prestador'),
            ),
          ],
        ),
      );
    }

    return null;
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

      // garante que existe row em providers (idempotente)
      try {
        await _supabase.rpc('provider_ensure_profile');
      } catch (_) {}

      // descobre role
      await _loadRoles();

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

  Future<File?> _cropSquare(File file) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar foto',
            toolbarColor: kRoxo,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: kLaranja,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Ajustar foto',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (cropped == null) return null;
      return File(cropped.path);
    } catch (e) {
      debugPrint('Erro no crop: $e');
      return null;
    }
  }

  Future<XFile?> _pickWithFallback() async {
    // 1) tenta galeria
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked != null) return picked;
    } catch (e) {
      debugPrint('Falhou galeria: $e');
    }

    // 2) fallback: câmera
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 85,
      );
      return picked;
    } catch (e) {
      debugPrint('Falhou câmera: $e');
      return null;
    }
  }

  // ✅ Cache + Crop + Fallback + Upload + RPC
  Future<void> _pickAndUploadAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _uploadingAvatar) return;

    try {
      if (!mounted) return;
      setState(() => _uploadingAvatar = true);

      await _loadRoles();

      // Nesta tela, o normal é provider. Se for both, perguntamos.
      String role = 'provider';
      final chosen = await _selectRoleIfNeeded();
      if (chosen == null) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finalize seu cadastro antes de alterar a foto.'),
          ),
        );
        return;
      }
      role = chosen;

      final picked = await _pickWithFallback();
      if (picked == null) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        return;
      }

      final originalFile = File(picked.path);

      // Crop quadrado (se cancelar, não faz upload)
      final croppedFile = await _cropSquare(originalFile);
      if (croppedFile == null) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        return;
      }

      final fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final storagePath = '$role/${user.id}/$fileName';

      await _supabase.storage.from('avatars').upload(
            storagePath,
            croppedFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(storagePath).trim();

      await _supabase.rpc('set_user_avatar_url', params: {
        'p_role': role,
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
    } catch (e, st) {
      debugPrint('Erro ao atualizar avatar: $e');
      debugPrint('$st');
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
    _comingSoon('Tela de Termos de uso ainda não implementada.');
  }

  void _openPrivacy() {
    _comingSoon('Tela de Política de privacidade ainda não implementada.');
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

  Future<void> _loadMyServicesFromView() async {
    setState(() => _loadingServices = true);

    try {
      await _supabase.from('v_provider_me').select('provider_id').maybeSingle();
      final providerId = _providerId;

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
        items.add(
          _ProviderCategoryItem(categoryName: 'Serviço', serviceName: name),
        );
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

  Widget _avatarWidget() {
    final url = (_avatarUrl ?? '').trim();

    if (url.isEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: kRoxo.withOpacity(0.1),
        child: const Icon(Icons.person, color: kRoxo, size: 30),
      );
    }

    // Cached + fallback
    return CircleAvatar(
      radius: 30,
      backgroundColor: kRoxo.withOpacity(0.1),
      backgroundImage: CachedNetworkImageProvider(url),
      onBackgroundImageError: (_, __) {
        debugPrint('Erro ao carregar avatar: $url');
      },
      child: const SizedBox.shrink(),
    );
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
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Minha conta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_uploadingAvatar)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                ],
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
                                      _avatarWidget(),
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
                                      // ❌ Removido: navegação para tela de seleção/edição (cadastro antigo)
                                      TextButton(
                                        onPressed: () => _comingSoon(
                                          'Edição de serviços será habilitada em breve.',
                                        ),
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
                                  leading: const Icon(Icons.person_outline,
                                      color: kRoxo),
                                  title: const Text('Meu perfil'),
                                  subtitle: const Text(
                                    'Veja seus dados pessoais e endereço.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45),
                                  onTap: _openProfileReadOnly,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                      Icons.card_giftcard_outlined,
                                      color: kLaranja),
                                  title: const Text('Indique e ganhe'),
                                  subtitle: const Text(
                                    'Compartilhe o Renthus com seus amigos.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45),
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
                                      color: kRoxo),
                                  title: const Text('Central de ajuda'),
                                  subtitle: const Text(
                                    'Fale com a equipe Renthus pelo app.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45),
                                  onTap: _openHelpCenter,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                      Icons.description_outlined,
                                      color: Colors.black54),
                                  title: const Text('Termos de uso'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45),
                                  onTap: _openTerms,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                      Icons.privacy_tip_outlined,
                                      color: Colors.black54),
                                  title: const Text('Política de privacidade'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45),
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
                              leading:
                                  const Icon(Icons.logout, color: kLaranja),
                              title: const Text('Sair do app',
                                  style: TextStyle(fontSize: 14)),
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
    // ❌ Removido: ProviderPhoneVerificationPage (não será mais usado)
    _comingSoon('Edição de telefone será habilitada em breve.');
  }

  Future<void> _editAddressWithCep() async {
    // ❌ Removido: ProviderAddressStep3Page (não existe mais)
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
