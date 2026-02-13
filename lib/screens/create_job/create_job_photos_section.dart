import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _kRoxo = Color(0xFF3B246B);
const _kMaxPhotos = 3;

class CreateJobPhotosSection extends StatelessWidget {

  const CreateJobPhotosSection({
    super.key,
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });
  final List<XFile> photos;
  final VoidCallback onAddPhoto;
  final void Function(int index) onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final bool isMaxed = photos.length >= _kMaxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Adicionar fotos (opcional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${photos.length}/$_kMaxPhotos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isMaxed ? Colors.redAccent : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botão adicionar
            InkWell(
              onTap: isMaxed ? null : onAddPhoto,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMaxed
                        ? Colors.grey.shade300
                        : _kRoxo.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  color: isMaxed ? Colors.grey : _kRoxo,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Lista horizontal com miniaturas
            Expanded(
              child: SizedBox(
                height: 74,
                child: photos.isEmpty
                    ? Container(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Você pode adicionar até 3 fotos.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final img = photos[index];

                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.black12,
                                    ),
                                  ),
                                  child: Image(
                                    image: FileImage(File(img.path)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => onRemovePhoto(index),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        if (isMaxed) ...[
          const SizedBox(height: 8),
          const Text(
            'Limite de 3 fotos atingido.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
