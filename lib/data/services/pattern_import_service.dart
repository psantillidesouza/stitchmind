import 'api_client.dart';

/// Importa receitas via backend (`/v1/patterns/import`), que usa IA para
/// converter texto/link numa estrutura carreira-a-carreira.
class PatternImportService {
  PatternImportService(this._api);
  final ApiClient _api;

  /// Receita a partir de texto colado. Devolve o JSON normalizado (contrato
  /// de `Pattern.fromJson`).
  Future<Map<String, dynamic>> importText(String text) =>
      _import({'text': text});

  /// Receita a partir de um link.
  Future<Map<String, dynamic>> importUrl(String url) => _import({'url': url});

  /// Receita a partir de um arquivo local (foto ou PDF). Envia multipart.
  Future<Map<String, dynamic>> importFile(String filePath) async {
    final res = await _api.postFile(
      '/v1/patterns/import',
      filePath,
      field: 'file',
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> _import(Map<String, dynamic> body) async {
    final res = await _api.post('/v1/patterns/import', body);
    return _unwrap(res);
  }

  Map<String, dynamic> _unwrap(dynamic res) {
    if (res is Map && res['pattern'] is Map) {
      return (res['pattern'] as Map).cast<String, dynamic>();
    }
    final msg = (res is Map ? res['error'] : null) ?? 'Resposta inválida.';
    throw Exception(msg.toString());
  }
}
