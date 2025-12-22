import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class CompressedImage {
  final Uint8List mainBytes;
  final Uint8List thumbBytes;

  CompressedImage({
    required this.mainBytes,
    required this.thumbBytes,
  });
}

class ImageUtils {
  /// Comprime a imagem original (até ~1600px) e gera um thumb (~300px).
  static Future<CompressedImage> compressWithThumb(
    Uint8List data, {
    int mainSize = 1600,
    int thumbSize = 300,
    int mainQuality = 80,
    int thumbQuality = 70,
  }) async {
    // Arquivo "principal" (para zoom)
    final main = await FlutterImageCompress.compressWithList(
      data,
      quality: mainQuality,
      minWidth: mainSize,
      minHeight: mainSize,
    );

    // Thumb pequeno (lista / grid)
    final thumb = await FlutterImageCompress.compressWithList(
      data,
      quality: thumbQuality,
      minWidth: thumbSize,
      minHeight: thumbSize,
    );

    return CompressedImage(
      mainBytes: Uint8List.fromList(main),
      thumbBytes: Uint8List.fromList(thumb),
    );
  }
}
