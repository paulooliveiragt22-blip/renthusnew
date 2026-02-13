// lib/screens/profile_screen.dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/auth_provider.dart';
import 'package:renthus/core/providers/supabase_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AuthService get _auth => ref.read(authServiceProvider);

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _role = 'client'; // client | provider
  String? _avatarUrl;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final client = ref.read(supabaseProvider);
      final user = client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usu?rio n?o autenticado')),
          );
          Navigator.of(context).maybePop();
        }
        return;
      }

      // Email vem do auth
      _emailCtrl.text = user.email ?? '';

      final profile = await _auth.getProfile();

      if (profile != null) {
        _nameCtrl.text = (profile['name'] ?? '').toString();
        _phoneCtrl.text = (profile['phone'] ?? '').toString();
        _role = (profile['role'] ?? 'client').toString();
        _avatarUrl = profile['avatar_url']?.toString();
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // importante p/ desktop
      );

      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.single;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('N?o foi poss?vel ler o arquivo selecionado')),
          );
        }
        return;
      }

      setState(() {
        _saving = true;
      });

      // Faz upload no bucket `avatars` usando AuthService
      final url = await _auth.uploadAvatar(
        bytes,
        originalFileName: file.name,
      );

      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao enviar avatar')),
          );
        }
        return;
      }

      // Atualiza profile com a nova URL do avatar
      await _auth.updateProfile(
        name: _nameCtrl.text.trim().isEmpty ? 'Sem nome' : _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _role,
        avatarUrl: url,
      );

      if (mounted) {
        setState(() {
          _avatarUrl = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada com sucesso')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao alterar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao alterar foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
    });

    try {
      await _auth.updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _role,
        // avatarUrl permanece o mesmo se n?o tiver alterado
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil salvo com sucesso')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'provider':
        return 'Prestador';
      case 'client':
      default:
        return 'Cliente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _saving,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: _avatarUrl != null
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                                  child: _avatarUrl == null
                                      ? const Icon(Icons.person, size: 60)
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _pickAndUploadAvatar,
                                  child: const Text('Alterar foto'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Nome completo',
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Seu nome',
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Email',
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                          TextFormField(
                            controller: _emailCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Telefone',
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Telefone/WhatsApp',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Tipo de conta',
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _role,
                            items: const [
                              DropdownMenuItem(
                                value: 'client',
                                child: Text('Cliente'),
                              ),
                              DropdownMenuItem(
                                value: 'provider',
                                child: Text('Prestador'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _role = value;
                              });
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveProfile,
                              icon: const Icon(Icons.save),
                              label: const Text('Salvar'),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (_saving)
                    Container(
                      color: Colors.black.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
