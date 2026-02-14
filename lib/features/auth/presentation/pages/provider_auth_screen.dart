import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/jobs.dart' show ProviderHomePage;

class ProviderAuthScreen extends ConsumerStatefulWidget {
  const ProviderAuthScreen({super.key});

  @override
  ConsumerState<ProviderAuthScreen> createState() => _ProviderAuthScreenState();
}

class _ProviderAuthScreenState extends ConsumerState<ProviderAuthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthAndNavigate();
    });
  }

  Future<void> _handleAuthAndNavigate() async {
    final user = ref.read(currentUserProvider);

    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum usuário logado. Faça login primeiro.'),
        ),
      );
      return;
    }

    context.goToProviderHome();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
