import 'package:flutter/material.dart';

/// Tela de visualização de imagem em tela cheia.
/// Usada via GoRouter: context.pushFullImage(url).
class FullScreenImagePage extends StatelessWidget {
  const FullScreenImagePage({super.key, required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white70,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
