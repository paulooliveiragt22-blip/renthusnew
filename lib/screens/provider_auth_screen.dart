import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'provider_home_page.dart';

class ProviderAuthScreen extends StatefulWidget {
  const ProviderAuthScreen({super.key});

  @override
  State<ProviderAuthScreen> createState() => _ProviderAuthScreenState();
}

class _ProviderAuthScreenState extends State<ProviderAuthScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // assim que essa tela abrir, decidimos pra onde mandar o usuário
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthAndNavigate();
    });
  }

  Future<void> _handleAuthAndNavigate() async {
    final user = supabase.auth.currentUser;

    if (!mounted) return;

    if (user == null) {
      // se quiser, aqui você pode mandar para a tela de login
      // por enquanto só mostra uma mensagem simples
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum usuário logado. Faça login primeiro.'),
        ),
      );
      // você pode trocar isso por:
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const LoginScreen()),
      // );
      return;
    }

    // Usuário logado → vai direto para a Home do Prestador
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderHomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Enquanto decide, mostra apenas um loading
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
