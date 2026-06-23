import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../../core/config/server_config.dart';
import 'auth_service.dart';

/// Mantém uma conexão WebSocket viva com o backend para presença em tempo real:
/// informa a tela atual, manda heartbeat e reconecta com backoff.
class RealtimeService {
  RealtimeService(this._auth);

  final AuthService _auth;

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _backoffMs = 1000;
  bool _disposed = false;

  String? _currentScreen;
  final String _platform = defaultTargetPlatform.name;
  String _appVersion = '0.0.0';

  void configure({required String appVersion}) {
    _appVersion = appVersion;
  }

  String get _wsUrl {
    final base = ServerConfig.url.replaceFirst(RegExp(r'^http'), 'ws');
    return '$base/v1/rt/app';
  }

  Future<void> connect() async {
    if (_disposed) return;
    try {
      final token = await _auth.idToken();
      final uri = Uri.parse('$_wsUrl${token != null ? '?token=$token' : ''}');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // captura "connection refused" sem estourar exceção não tratada
      channel.ready.catchError((_) => _scheduleReconnect());

      channel.stream.listen(
        (_) {},
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );

      _backoffMs = 1000; // reset
      // reenvia a tela atual ao reconectar
      if (_currentScreen != null) setScreen(_currentScreen!);

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _ping());
    } catch (_) {
      _channel = null;
      _scheduleReconnect();
    }
  }

  void setScreen(String name) {
    _currentScreen = name;
    _send({
      'type': 'screen',
      'name': name,
      'platform': _platform,
      'app_version': _appVersion,
    });
  }

  /// Empurra um evento de ação para o feed ao vivo (ex.: lesson_play).
  void liveEvent(String name) {
    _send({'type': 'event', 'name': name});
  }

  void _ping() => _send({'type': 'ping'});

  void _send(Map<String, dynamic> msg) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _channel = null;
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), connect);
    _backoffMs = (_backoffMs * 2).clamp(1000, 30000);
  }

  void dispose() {
    _disposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _channel?.sink.close(ws_status.goingAway);
    } catch (_) {}
  }
}
