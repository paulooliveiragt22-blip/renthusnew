import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/services/fcm_device_sync.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/widgets/password_confirm_dialog.dart';
import 'package:renthus/features/auth/data/providers/auth_providers.dart';

const _kRoxo = Color(0xFF3B246B);
const _kLaranja = Color(0xFFFF6600);

class ProviderProfilePage extends ConsumerStatefulWidget {
  const ProviderProfilePage({super.key});

  @override
  ConsumerState<ProviderProfilePage> createState() =>
      _ProviderProfilePageState();
}

class _ProviderProfilePageState extends ConsumerState<ProviderProfilePage> {
  bool _loading = true;

  String? _name;
  String? _emailAuth;
  String? _phone;
  String? _city;
  String? _state;
  String? _avatarUrl;
  String? _cep;
  String? _street;
  String? _number;
  String? _district;
  DateTime? _createdAt;

  int _totalJobsCompleted = 0;
  String _rating = '0.0';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      _emailAuth = user.email;

      // View v_provider_me: provider_id, full_name, phone, avatar_url, city, state,
      // cep, address_street, address_number, address_district, rating, created_at (e demais)
      final row = await supabase
          .from('v_provider_me')
          .select(
            'provider_id, full_name, phone, avatar_url, city, state, '
            'cep, address_street, address_number, address_district, '
            'rating, created_at',
          )
          .maybeSingle();

      final res = row != null ? Map<String, dynamic>.from(row as Map) : null;
      _name = _str(res, 'full_name');
      _phone = _str(res, 'phone');
      _city = _str(res, 'city');
      _state = _str(res, 'state');
      _avatarUrl = _str(res, 'avatar_url');
      _cep = _str(res, 'cep') ?? _str(res, 'address_cep');
      _street = _str(res, 'address_street');
      _number = _str(res, 'address_number');
      _district = _str(res, 'address_district');
      _rating = (res?['rating']?.toString()) ?? '0.0';
      final createdRaw = res?['created_at'];
      _createdAt = createdRaw != null
          ? (createdRaw is DateTime
              ? createdRaw
              : DateTime.tryParse(createdRaw.toString()))
          : null;

      final providerId = res?['provider_id']?.toString();
      if (providerId != null && providerId.isNotEmpty) {
        try {
          final jobsRes = await supabase
              .from('jobs')
              .select()
              .eq('provider_id', providerId)
              .eq('status', 'completed');
          _totalJobsCompleted = (jobsRes as List).length;
        } catch (_) {
          _totalJobsCompleted = 0;
        }
      }

      if (!mounted) return;

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    }
  }

  String? _str(Map<String, dynamic>? m, String key) {
    final v = m?[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _formatLocation() {
    if ((_city ?? '').isEmpty) return 'Cidade não informada';
    if ((_state ?? '').isEmpty) return _city ?? '';
    return '${_city ?? ''} - ${_state ?? ''}';
  }

  String _formatMemberSince(DateTime? date) {
    if (date == null) return '';
    const months = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    return '${months[date.month - 1]}/${date.year}';
  }

  Widget _buildStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _kRoxo.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kRoxo,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Map<String, String> fields,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kRoxo,
                  ),
                ),
              ),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Editar',
                    style: TextStyle(
                      fontSize: 12,
                      color: _kLaranja,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...fields.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value.isEmpty ? '—' : e.value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text(
          'Essa ação não poderá ser desfeita.\n\n'
          'Seu cadastro será removido, mas os registros de serviços '
          'já realizados serão mantidos por segurança.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final supabase = ref.read(supabaseProvider);
    final passwordOk = await showPasswordConfirmDialog(context, supabase);
    if (passwordOk != true) return;

    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final supabase = ref.read(supabaseProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(providerRepositoryProvider);
      await repo.deleteAccount();
      await FcmDeviceSync.removeCurrentDevice();
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pop(context);
      context.goToHome();
    } catch (e) {
      debugPrint('Erro ao cancelar conta provider (RPC): $e');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    }
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await context.pushProviderEditData();
                              await _loadProfile();
                            },
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: _kRoxo.withOpacity(0.1),
                                  backgroundImage: _avatarUrl != null
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                                  child: _avatarUrl == null
                                      ? const Icon(
                                          Icons.person,
                                          color: _kRoxo,
                                          size: 50,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _kRoxo,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _name ?? 'Prestador Renthus',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatLocation(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _createdAt == null
                                ? ''
                                : 'Membro desde ${_formatMemberSince(_createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStat(
                                _totalJobsCompleted.toString(),
                                'Serviços concluídos',
                              ),
                              const SizedBox(width: 24),
                              _buildStat(
                                '⭐ $_rating',
                                'Avaliação',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Dados pessoais',
                      fields: {
                        'Nome': _name ?? '',
                        'Email': _emailAuth ?? '',
                        'Telefone': _phone ?? '',
                      },
                      onEdit: () async {
                        await context.pushProviderEditData();
                        await _loadProfile();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Endereço de atendimento',
                      fields: {
                        'Rua': _street ?? '',
                        'Número': _number ?? '',
                        'Bairro': _district ?? '',
                        'Cidade':
                            '${_city ?? ''}${(_state ?? '').isNotEmpty ? ' - $_state' : ''}',
                        'CEP': _cep ?? '',
                      },
                      onEdit: () async {
                        await context.pushProviderEditData();
                        await _loadProfile();
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
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
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Segurança',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kRoxo,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.lock_outline,
                              color: _kRoxo,
                              size: 20,
                            ),
                            title: const Text(
                              'Alterar senha',
                              style: TextStyle(fontSize: 14),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.black45,
                              size: 20,
                            ),
                            dense: true,
                            onTap: () => context.pushForgotPassword(),
                          ),
                          const Divider(height: 0, indent: 16, endIndent: 16),
                          ListTile(
                            leading: const Icon(
                              Icons.email_outlined,
                              color: _kRoxo,
                              size: 20,
                            ),
                            title: const Text(
                              'Alterar email',
                              style: TextStyle(fontSize: 14),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.black45,
                              size: 20,
                            ),
                            dense: true,
                            onTap: () async {
                              final result = await context
                                  .pushClientEditEmail<bool>(_emailAuth ?? '');
                              if (result == true) {
                                await _loadProfile();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmDeleteAccount,
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                          size: 18,
                        ),
                        label: const Text(
                          'Excluir minha conta',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
