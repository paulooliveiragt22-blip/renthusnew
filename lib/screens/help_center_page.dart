import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

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
