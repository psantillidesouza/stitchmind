import 'package:shared_preferences/shared_preferences.dart';

/// URL do servidor de IA — configurável pela usuária via tela de Perfil.
class ServerConfig {
  ServerConfig._();

  static const _key = 'ai_server_url';
  // API de produção (Bun: tips, aulas, chat, realtime, telemetria).
  // A API responde tanto em /api quanto em /v1 (o app usa /v1).
  static const defaultUrl = 'https://stitchmindapp.com';

  static String _cached = defaultUrl;

  static String get url => _cached;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(_key) ?? defaultUrl;
  }

  static Future<void> setUrl(String value) async {
    _cached = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _cached);
  }
}
