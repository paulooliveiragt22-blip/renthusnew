import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos de uso'),
        backgroundColor: kRoxo,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Em breve.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
