import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Pipeline único para QUALQUER foto que entra no app.
///
/// Regra do produto: toda imagem enviada deve virar WebP. A conversão acontece
/// aqui, no aparelho, antes de subir (economiza dados). Onde o sistema não
/// codifica WebP (alguns casos no iOS), caímos em JPEG — e o servidor ainda
/// reconverte para WebP no recebimento, garantindo o formato no armazenamento.
class ImagePipeline {
  ImagePipeline._();

  static final ImagePicker _picker = ImagePicker();

  /// Abre a câmera/galeria, redimensiona e converte para WebP.
  /// Retorna `null` se o usuário cancelar.
  static Future<File?> pick(
    ImageSource source, {
    int maxWidth = 1568,
    int quality = 85,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
    );
    if (picked == null) return null;
    return toWebp(File(picked.path), maxWidth: maxWidth, quality: quality);
  }

  /// Converte um arquivo de imagem existente para WebP (com fallback p/ JPEG).
  /// Nunca lança: se a conversão falhar, devolve o arquivo original.
  static Future<File> toWebp(
    File input, {
    int maxWidth = 1568,
    int quality = 85,
  }) async {
    final dir = input.parent.path;
    final stamp = DateTime.now().microsecondsSinceEpoch;

    // 1) Tenta WebP (ideal — Android codifica nativamente).
    final webp = await _compress(
      input.path,
      '$dir/sm_$stamp.webp',
      CompressFormat.webp,
      maxWidth,
      quality,
    );
    if (webp != null) return webp;

    // 2) Fallback: JPEG (o servidor reconverte p/ WebP no upload).
    final jpg = await _compress(
      input.path,
      '$dir/sm_$stamp.jpg',
      CompressFormat.jpeg,
      maxWidth,
      quality,
    );
    return jpg ?? input;
  }

  static Future<File?> _compress(
    String from,
    String to,
    CompressFormat format,
    int maxWidth,
    int quality,
  ) async {
    try {
      final out = await FlutterImageCompress.compressAndGetFile(
        from,
        to,
        format: format,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxWidth,
        keepExif: false,
      );
      return out == null ? null : File(out.path);
    } catch (_) {
      return null;
    }
  }
}
