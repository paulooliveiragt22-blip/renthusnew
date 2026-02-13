import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

import 'package:renthus/screens/role_selection_page.dart';
import 'package:renthus/screens/partner_stores_page.dart';

import 'package:renthus/screens/provider_profile_page.dart';
import 'package:renthus/screens/help_center_page.dart';
import 'package:renthus/screens/terms_of_use_page.dart';
import 'package:renthus/screens/privacy_policy_page.dart';
import 'package:renthus/screens/provider_services_page.dart';

const kRoxo = Color(0xFF3B246B);
const kLaranja = Color(0xFFFF6600);

final _imagePicker = ImagePicker();

/// =======================
/// MINHA CONTA (PRESTADOR)
/// =======================
class ProviderAccountPage extends ConsumerStatefulWidget {
  const ProviderAccountPage({super.key});

  @override
  ConsumerState<ProviderAccountPage> createState() => _ProviderAccountPageState();
}

class _ProviderAccountPageState extends ConsumerState<ProviderAccountPage> {
  bool _loadingProfile = true;

  // Tudo vem de v_provider_me
  String? _providerId;
  String? _fullName;
  String? _city;
  String? _stateUf;
  String? _phone;
  String? _emailAuth;
  String? _avatarUrl;

  // endereço (reservado para futuro)
  // ignore: unused_field
  String? _cep;
  // ignore: unused_field
  String? _street;
  // ignore: unused_field
  String? _number;
  // ignore: unused_field
  String? _district;

  bool _uploadingAvatar = false;

  // role detectado via RPC
  String? _defaultRole; // client | provider | both | null

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    await _loadProfileFromView();
  }

  // ignore: unused_element
  void _comingSoon([String msg = 'Em breve.']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadRoles() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase.rpc('get_my_roles');
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
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;
      _emailAuth = user?.email;

      if (user == null) {
        if (!mounted) return;
        setState(() => _loadingProfile = false);
        return;
      }

      // garante que existe row em providers (idempotente)
      try {
        await supabase.rpc('provider_ensure_profile');
      } catch (_) {}

      // descobre role
      await _loadRoles();

      final me = await supabase.from('v_provider_me').select().maybeSingle();

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
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
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

      await supabase.storage.from('avatars').upload(
            storagePath,
            croppedFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from('avatars').getPublicUrl(storagePath).trim();

      await supabase.rpc('set_user_avatar_url', params: {
        'p_role': role,
        'p_avatar_url': publicUrl,
      },);

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
    final supabase = ref.read(supabaseProvider);
    await supabase.auth.signOut();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsOfUsePage(),
      ),
    );
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyPage(),
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

  void _openProviderServices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderServicesPage(providerId: _providerId),
      ),
    );
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
      final supabase = ref.read(supabaseProvider);
      await supabase.rpc('rpc_provider_delete_account');
      await supabase.auth.signOut();

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

                          // SERVIÇOS (atalho para tela)
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
                            child: ListTile(
                              leading: const Icon(
                                Icons.build_circle_outlined,
                                color: kRoxo,
                              ),
                              title: const Text('Minhas categorias e serviços'),
                              subtitle: const Text(
                                'Veja os serviços atendidos por você.',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.black45,
                              ),
                              onTap: _openProviderServices,
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
                                      color: kRoxo,),
                                  title: const Text('Meu perfil'),
                                  subtitle: const Text(
                                    'Veja seus dados pessoais e endereço.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45,),
                                  onTap: _openProfileReadOnly,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                      Icons.card_giftcard_outlined,
                                      color: kLaranja,),
                                  title: const Text('Indique e ganhe'),
                                  subtitle: const Text(
                                    'Compartilhe o Renthus com seus amigos.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45,),
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
                                      color: kRoxo,),
                                  title: const Text('Central de ajuda'),
                                  subtitle: const Text(
                                    'Fale com a equipe Renthus pelo app.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45,),
                                  onTap: _openHelpCenter,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                      Icons.description_outlined,
                                      color: Colors.black54,),
                                  title: const Text('Termos de uso'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45,),
                                  onTap: _openTerms,
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(
                                      Icons.privacy_tip_outlined,
                                      color: Colors.black54,),
                                  title: const Text('Política de privacidade'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.black45,),
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
                                  style: TextStyle(fontSize: 14),),
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
                                foregroundColor: Colors.red,),
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
