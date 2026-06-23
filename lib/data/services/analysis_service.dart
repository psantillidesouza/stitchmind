import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../l10n/loc.dart';
import '../../core/config/server_config.dart';
import '../../core/media/mime.dart';
import '../../domain/entities/ai_analysis.dart';
import 'auth_service.dart';

class AnalysisServiceException implements Exception {
  AnalysisServiceException(this.message);
  final String message;
  @override
  String toString() => 'AnalysisServiceException: $message';
}

class AnalysisService {
  AnalysisService(this._auth);
  final AuthService _auth;

  Future<AiAnalysis> analyzeImage(File image) async {
    final uri = Uri.parse('${ServerConfig.url}/analyze');
    final token = await _auth.idToken();

    // Define o content-type pela extensão — sem isso vai como octet-stream
    // e o servidor recusa ("Tipo não suportado").
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: imageMediaType(image.path),
      ));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final streamed = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw AnalysisServiceException(
        tr2('Timed out: the server took more than 60s.', 'Tempo limite: o servidor demorou mais de 60s.'),
      ),
    );
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      String msg = 'HTTP ${streamed.statusCode}';
      try {
        final j = jsonDecode(body) as Map<String, dynamic>;
        msg = (j['error'] as String?) ?? msg;
      } catch (_) {}
      throw AnalysisServiceException(msg);
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return AiAnalysis.fromJson({
      ...json,
      'created_at': DateTime.now().toIso8601String(),
      'image_path': image.path,
    });
  }

  Future<void> sendFeedback({
    required String analysisId,
    required String section,
    required String rating,
    String? note,
  }) async {
    final uri = Uri.parse('${ServerConfig.url}/feedback');
    final token = await _auth.idToken();
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'analysis_id': analysisId,
        'section': section,
        'rating': rating,
        if (note != null) 'note': note,
      }),
    );
    if (response.statusCode != 200) {
      throw AnalysisServiceException(
        tr2('Feedback failed: HTTP ${response.statusCode}', 'Feedback falhou: HTTP ${response.statusCode}'),
      );
    }
  }
}
