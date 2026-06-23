import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/server_config.dart';
import '../../core/media/mime.dart';
import 'auth_service.dart';

/// Cliente HTTP central: injeta o token de auth e centraliza o base URL.
class ApiClient {
  ApiClient(this._auth);

  final AuthService _auth;

  String get _base => ServerConfig.url;

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _auth.idToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) async {
    final res = await http
        .get(Uri.parse('$_base$path'), headers: await _headers(json: false))
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<dynamic> post(String path, [Object? body]) async {
    final res = await http
        .post(
          Uri.parse('$_base$path'),
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  Future<dynamic> patch(String path, [Object? body]) async {
    final res = await http
        .patch(
          Uri.parse('$_base$path'),
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  /// Envia um arquivo via multipart (campo [field]) com o token de auth.
  /// [fields] adiciona campos de texto extras ao form (ex.: legenda).
  Future<dynamic> postFile(
    String path,
    String filePath, {
    String field = 'image',
    Map<String, String>? fields,
  }) async {
    final token = await _auth.idToken();
    final request = http.MultipartRequest('POST', Uri.parse('$_base$path'))
      ..files.add(await http.MultipartFile.fromPath(
        field,
        filePath,
        contentType: fileMediaType(filePath),
      ));
    if (fields != null) request.fields.addAll(fields);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http
        .delete(Uri.parse('$_base$path'), headers: await _headers(json: false))
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  /// POST que não lança em falha de rede (telemetria/crash são best-effort).
  Future<bool> postSilent(String path, Object body) async {
    try {
      await http
          .post(
            Uri.parse('$_base$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Como [postSilent], mas devolve o JSON decodificado (ou null em falha).
  Future<Map<String, dynamic>?> postSilentJson(String path, Object body) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 400) return null;
      final json = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? '{}' : res.body;
    final json = jsonDecode(body);
    if (res.statusCode >= 400) {
      throw ApiException(
        (json is Map && json['error'] != null)
            ? json['error'].toString()
            : 'HTTP ${res.statusCode}',
        res.statusCode,
      );
    }
    return json;
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => 'ApiException($statusCode): $message';
}
