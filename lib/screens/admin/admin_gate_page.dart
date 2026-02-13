import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

import 'admin_home_page.dart';

class AdminGatePage extends ConsumerStatefulWidget {
  const AdminGatePage({super.key});

  @override
  ConsumerState<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends ConsumerState<AdminGatePage> {

  bool isLoading = true;
  String? error;
  bool allowed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      isLoading = true;
      error = null;
      allowed = false;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase.rpc('is_admin');
      setState(() {
        allowed = (res == true);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = '$e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: Center(child: Text('Erro: $error')),
      );
    }

    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 44),
              const SizedBox(height: 10),
              const Text('Sem permissão de administrador.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _check,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return const AdminHomePage();
  }
}
