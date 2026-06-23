import 'package:http_parser/http_parser.dart';

/// MediaType de imagem a partir da extensão do arquivo.
///
/// `http.MultipartFile.fromPath` NÃO detecta o tipo pela extensão — sem
/// `contentType` ele manda `application/octet-stream`, que o servidor recusa.
/// Use isto sempre que subir uma imagem por multipart.
MediaType imageMediaType(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'webp' => MediaType('image', 'webp'),
    'png' => MediaType('image', 'png'),
    'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
    _ => MediaType('image', 'jpeg'),
  };
}

/// Como [imageMediaType], mas também reconhece PDF — usado no import de
/// receitas (foto ou PDF). Default cai em imagem JPEG.
MediaType fileMediaType(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => MediaType('application', 'pdf'),
    'webp' => MediaType('image', 'webp'),
    'png' => MediaType('image', 'png'),
    'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
    _ => imageMediaType(path),
  };
}
