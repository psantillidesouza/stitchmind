import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Coleta telemetria do app: registra device, abre/fecha sessão e envia
/// eventos (screen_view + custom) em batch para o backend.
class TelemetryService {
  TelemetryService(this._api);

  final ApiClient _api;

  String? _deviceId;
  String? _sessionId;
  String _appVersion = '0.0.0';
  final String _platform = defaultTargetPlatform.name;

  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;

  // Breadcrumbs (últimas telas/eventos) para anexar a crashes.
  final List<String> breadcrumbs = [];

  // Tela atual + última mudança (usado p/ heatmaps e dead-tap).
  String? currentScreen;
  DateTime lastScreenChangeAt = DateTime.fromMillisecondsSinceEpoch(0);

  String? get deviceId => _deviceId;
  String? get sessionId => _sessionId;
  String get appVersion => _appVersion;
  String get platform => _platform;

  Future<void> init() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      _appVersion = pkg.version;
    } catch (_) {}

    final info = await _collectDevice();
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('telemetry_device_id');

    final res = await _api.postSilentJson('/v1/devices/register', {
      if (cached != null) 'device_id': cached,
      'platform': _platform,
      'model': info['model'],
      'os_version': info['os_version'],
      'app_version': _appVersion,
    });
    _deviceId = (res?['device_id'] as String?) ?? cached;
    if (_deviceId != null) await prefs.setString('telemetry_device_id', _deviceId!);

    await _startSession();
    _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) => flush());
  }

  Future<Map<String, String?>> _collectDevice() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await plugin.iosInfo;
        return {'model': i.utsname.machine, 'os_version': i.systemVersion};
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await plugin.androidInfo;
        return {'model': a.model, 'os_version': a.version.release};
      }
    } catch (_) {}
    return {'model': null, 'os_version': null};
  }

  Future<void> _startSession() async {
    final res = await _api.postSilentJson('/v1/sessions/start', {
      'device_id': _deviceId,
      'app_version': _appVersion,
      'platform': _platform,
    });
    _sessionId = res?['session_id'] as String?;
  }

  Future<void> endSession() async {
    if (_sessionId == null) return;
    await _api.postSilent('/v1/sessions/end', {'session_id': _sessionId});
  }

  /// Registra um evento (entra na fila; envia em batch).
  void track(String name, {String? screen, Map<String, dynamic>? props}) {
    breadcrumbs.add('$name${screen != null ? "($screen)" : ""}');
    if (breadcrumbs.length > 20) breadcrumbs.removeAt(0);
    _queue.add({
      'name': name,
      if (screen != null) 'screen': screen,
      if (props != null) 'props': props,
      'app_version': _appVersion,
      'platform': _platform,
      'ts': DateTime.now().toUtc().toIso8601String(),
      if (_deviceId != null) 'device_id': _deviceId,
      if (_sessionId != null) 'session_id': _sessionId,
    });
    if (_queue.length >= 20) flush();
  }

  void trackScreen(String screen) {
    currentScreen = screen;
    lastScreenChangeAt = DateTime.now();
    track('screen_view', screen: screen);
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    final ok = await _api.postSilent('/v1/events', {'events': batch});
    if (!ok) _queue.insertAll(0, batch); // recoloca para retry
  }

  void dispose() {
    _flushTimer?.cancel();
  }
}
