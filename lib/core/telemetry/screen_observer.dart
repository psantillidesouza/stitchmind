import 'package:flutter/widgets.dart';

import '../../data/services/realtime_service.dart';
import '../../data/services/telemetry_service.dart';

/// Observa a navegação (go_router) e dispara `screen_view` a cada tela —
/// para o batch de telemetria E para a presença em tempo real (WebSocket).
class TelemetryNavigatorObserver extends NavigatorObserver {
  TelemetryNavigatorObserver(this._telemetry, this._realtime);

  final TelemetryService _telemetry;
  final RealtimeService _realtime;

  void _send(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      final screen = _normalize(name);
      _telemetry.trackScreen(screen);
      _realtime.setScreen(screen);
    }
  }

  String _normalize(String path) {
    if (path == '/') return 'painel';
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    return seg.isEmpty ? 'painel' : seg.first;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _send(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _send(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _send(newRoute);
}
