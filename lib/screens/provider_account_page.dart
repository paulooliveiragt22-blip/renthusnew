import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/services/fcm_device_sync.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';

const kRoxo = Color(0xFF3B246B);
const kLaranja = Color(0xFFFF6600);

final _imagePicker = ImagePicker();

/// =======================
/// MINHA CONTA (PRESTADOR)
/// =======================
class ProviderAccountPage extends ConsumerStatefulWidget {
  const ProviderAccountPage({super.key});

  @override
  ConsumerState<ProviderAccountPage> createState() =>
      _ProviderAccountPageState();
}

class _ProviderAccountPageState extends ConsumerState<ProviderAccountPage> {
  bool _uploadingAvatar = false;

  static String formatLocation(String? city, String? stateUf) {
    final c = city ?? '';
    final s = stateUf ?? '';
    if (c.isEmpty && s.isEmpty) return 'Cidade não informada';
    if (c.isNotEmpty && s.isEmpty) return c;
    if (c.isEmpty && s.isNotEmpty) return s;
    return '$c - $s';
  }

  Future<String?> _selectRoleIfNeeded(String? defaultRole) async {
    if (defaultRole == 'client' || defaultRole == 'provider') {
      return defaultRole;
    }

    if (defaultRole == 'both') {
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

  Future<String?> _showAvatarSourceDialog(bool hasAvatar) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (hasAvatar)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remover foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ListTile(
              title: const Text('Cancelar', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Solicita permissão de câmera (apenas câmera — galeria usa Intent do sistema
  /// e não requer permissão em runtime no Android nem no iOS).
  Future<bool> _requestCameraPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    status = await Permission.camera.request();

    if ((status.isDenied || status.isPermanentlyDenied) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Permissão de câmera negada. Habilite nas configurações.',
          ),
          action: SnackBarAction(
            label: 'Configurações',
            onPressed: openAppSettings,
          ),
        ),
      );
      return false;
    }
    return status.isGranted || status.isLimited;
  }

  Future<File?> _pickImage(String source) async {
    if (source == 'camera') {
      final hasPermission = await _requestCameraPermission();
      if (!hasPermission) return null;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked != null) return File(picked.path);
    } catch (e) {
      debugPrint('Falhou $source: $e');
      // fallback: se câmera falhou, tenta galeria (sem permissão extra)
      if (source == 'camera') {
        try {
          final picked = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1200,
            imageQuality: 85,
          );
          if (picked != null) return File(picked.path);
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _pickAndUploadAvatar(String? defaultRole) async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null || _uploadingAvatar) return;

    final currentAvatarUrl =
        ref.read(providerMeForAccountProvider).valueOrNull?['avatar_url']
            as String?;
    if (!mounted) return;

    final source =
        await _showAvatarSourceDialog((currentAvatarUrl ?? '').isNotEmpty);
    if (source == null || !mounted) return;

    try {
      setState(() => _uploadingAvatar = true);

      // Nesta tela, o normal é provider. Se for both, perguntamos.
      String role = 'provider';
      final chosen = await _selectRoleIfNeeded(defaultRole);
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

      if (source == 'remove') {
        await supabase.rpc(
          'set_user_avatar_url',
          params: {'p_role': role, 'p_avatar_url': null},
        );
        // best-effort: remove arquivo do storage
        try {
          await supabase.storage
              .from('avatars')
              .remove(['$role/${user.id}/avatar.jpg']);
        } catch (_) {}
        ref.invalidate(providerMeForAccountProvider);
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto removida.')),
        );
        return;
      }

      final imageFile = await _pickImage(source);
      if (imageFile == null) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        return;
      }

      // Validação de tamanho (max 5 MB)
      final bytes = await imageFile.length();
      if (bytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Imagem muito grande. Máximo 5 MB.')),
        );
        return;
      }

      // Crop quadrado (se cancelar, não faz upload)
      final croppedFile = await _cropSquare(imageFile);
      if (croppedFile == null) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        return;
      }

      // Caminho fixo → upsert sobrescreve sem acumular arquivos
      final storagePath = '$role/${user.id}/avatar.jpg';

      await supabase.storage.from('avatars').upload(
            storagePath,
            croppedFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from('avatars').getPublicUrl(storagePath).trim();

      await supabase.rpc(
        'set_user_avatar_url',
        params: {
          'p_role': role,
          'p_avatar_url': publicUrl,
        },
      );

      ref.invalidate(providerMeForAccountProvider);
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto atualizada com sucesso!')),
      );
    } catch (e, st) {
      debugPrint('Erro ao atualizar avatar: $e\n$st');
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    }
  }

  void _openPartnerStores() {
    context.pushPartnerStores();
  }

  void _shareInvite() {
    const link = 'https://www.renthus.com.br';
    const message =
        'Conheça o Renthus Service! Acesse e receba novos serviços na sua região: $link';
    Share.share(message);
  }

  Future<void> _signOut() async {
    final supabase = ref.read(supabaseProvider);
    await FcmDeviceSync.removeCurrentDevice();
    await supabase.auth.signOut();
    if (!mounted) return;
    context.goToHome();
  }

  void _openHelpCenter() {
    context.pushHelpCenter();
  }

  void _openTerms() {
    context.pushTerms();
  }

  void _openPrivacy() {
    context.pushPrivacy();
  }

  void _openProfileReadOnly() async {
    await context.pushProviderProfile();
    ref.invalidate(providerMeForAccountProvider);
  }

  void _openBankData() async {
    final changed = await context.pushProviderBankData<bool>();
    if (changed == true) {
      ref.invalidate(providerMeForAccountProvider);
    }
  }

  void _openProviderServices(String? providerId) {
    if (providerId != null) {
      context.pushProviderServices(providerId);
    }
  }

  Widget _avatarWidget(String? avatarUrl) {
    final url = (avatarUrl ?? '').trim();

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

  Future<void> _refresh() async {
    ref.invalidate(providerMeForAccountProvider);
    ref.invalidate(providerMyRolesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(providerMeForAccountProvider);
    final rolesAsync = ref.watch(providerMyRolesProvider);
    final emailAuth = ref.watch(supabaseProvider).auth.currentUser?.email;

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
              child: meAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(ErrorHandler.friendlyErrorMessage(e)),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  ref.invalidate(providerMeForAccountProvider),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                  data: (me) {
                    final fullName = (me?['full_name'] as String?)?.trim();
                    final city = me?['city'] as String?;
                    final stateUf = me?['state'] as String?;
                    final phone = me?['phone'] as String?;
                    final avatarUrl = me?['avatar_url'] as String?;
                    final providerId = me?['provider_id']?.toString();
                    final defaultRole = rolesAsync.valueOrNull;

                    return RefreshIndicator(
                      onRefresh: _refresh,
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
                                  onTap: () =>
                                      _pickAndUploadAvatar(defaultRole),
                                  child: Stack(
                                    children: [
                                      _avatarWidget(avatarUrl),
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
                                        fullName?.isNotEmpty == true
                                            ? fullName!
                                            : (emailAuth ??
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
                                        formatLocation(city, stateUf),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (phone?.isNotEmpty == true) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          phone!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      if (emailAuth != null &&
                                          emailAuth.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          emailAuth,
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
                              onTap: () => _openProviderServices(providerId),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // AVALIAÇÕES
                          const Text(
                            'Avaliações',
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
                                Icons.star_outline_rounded,
                                color: kRoxo,
                              ),
                              title: const Text('Minhas avaliações'),
                              subtitle: const Text(
                                'Veja o que seus clientes disseram.',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.black45,
                              ),
                              onTap: () {
                                if (providerId != null) {
                                  context.pushProviderReviews(
                                    providerId,
                                    isOwnProfile: true,
                                  );
                                }
                              },
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
                                    Icons.account_balance_outlined,
                                    color: kRoxo,
                                  ),
                                  title: const Text('Dados bancários'),
                                  subtitle: const Text(
                                    'Altere a conta para receber pagamentos.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black45,
                                  ),
                                  onTap: _openBankData,
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
                              leading:
                                  const Icon(Icons.logout, color: kLaranja),
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
                        ],
                      ),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
