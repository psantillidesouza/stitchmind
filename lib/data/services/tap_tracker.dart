import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'telemetry_service.dart';

/// Captura toques (para heatmap) e detecta sinais de frustração:
/// **rage tap** (vários toques no mesmo ponto em pouco tempo) e
/// **dead tap** (toque que não levou a navegação nenhuma).
class TapTracker {
  TapTracker(this._api, this._telemetry);

  final ApiClient _api;
  final TelemetryService _telemetry;

  final List<Map<String, dynamic>> _queue = [];
  final List<_RecentTap> _recent = [];
  Timer? _flushTimer;

  void start() {
    _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) => flush());
  }

  /// Chamado pelo Listener global a cada toque (posição global + tamanho da tela).
  void onTap(Offset position, Size screenSize) {
    if (screenSize.width <= 0 || screenSize.height <= 0) return;
    final x = (position.dx / screenSize.width).clamp(0.0, 1.0);
    final y = (position.dy / screenSize.height).clamp(0.0, 1.0);
    final now = DateTime.now();
    final screen = _telemetry.currentScreen;

    // rage: >=3 toques num raio pequeno em 1s
    _recent.removeWhere((t) => now.difference(t.at).inMilliseconds > 1000);
    _recent.add(_RecentTap(position, now));
    final near = _recent.where((t) => (t.pos - position).distance < 40).length;
    final isRage = near >= 3;

    final tap = <String, dynamic>{
      'screen': screen,
      'x': x,
      'y': y,
      'is_rage': isRage,
      'is_dead': false,
      'app_version': _telemetry.appVersion,
      'platform': _telemetry.platform,
      'ts': now.toUtc().toIso8601String(),
      if (_telemetry.deviceId != null) 'device_id': _telemetry.deviceId,
      if (_telemetry.sessionId != null) 'session_id': _telemetry.sessionId,
    };
    _queue.add(tap);

    // dead tap: se em 1.2s não houve mudança de tela, marca como morto
    final tapAt = now;
    Timer(const Duration(milliseconds: 1200), () {
      if (_telemetry.lastScreenChangeAt.isBefore(tapAt)) {
        tap['is_dead'] = true;
      }
    });

    if (isRage) _telemetry.track('rage_tap', screen: screen);
    if (_queue.length >= 30) flush();
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;
    // espera o veredito de dead-tap dos toques mais recentes
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    final ok = await _api.postSilent('/v1/taps', {'taps': batch});
    if (!ok) _queue.insertAll(0, batch);
  }

  void dispose() => _flushTimer?.cancel();
}

class _RecentTap {
  _RecentTap(this.pos, this.at);
  final Offset pos;
  final DateTime at;
}
