import 'package:flutter/material.dart';

class JobPhotosSection extends StatelessWidget {
  /// URLs das fotos em tamanho completo (para zoom).
  final List<String>? photos;

  /// URLs dos thumbs (opcional). Se não vier, usa `photos` como fallback.
  final List<String>? photoThumbs;

  const JobPhotosSection({
    super.key,
    required this.photos,
    this.photoThumbs,
  });

  @override
  Widget build(BuildContext context) {
    // Se não tiver nada, mostra mensagem
    if (photos == null || photos!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Nenhuma foto enviada pelo cliente.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    // Lista que será usada como thumb na horizontal
    final List<String> thumbsToShow =
        (photoThumbs != null && photoThumbs!.isNotEmpty)
            ? photoThumbs!
            : photos!; // fallback

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fotos do serviço',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: thumbsToShow.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final String thumbUrl = thumbsToShow[index];

                // URL completa pra abrir no zoom
                String fullUrl = thumbUrl;
                if (photos != null && index < photos!.length) {
                  fullUrl = photos![index];
                }

                if (thumbUrl.isEmpty) return const SizedBox();

                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(fullUrl, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      thumbUrl,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
