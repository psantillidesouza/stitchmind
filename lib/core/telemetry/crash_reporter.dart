import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/services/api_client.dart';
import '../../data/services/telemetry_service.dart';

/// Captura erros não tratados do Flutter e os envia para `/v1/crashes`.
class CrashReporter {
  CrashReporter(this._api, this._telemetry);

  final ApiClient _api;
  final TelemetryService _telemetry;

  /// Instala os handlers globais. Use [runZonedGuarded] no main envolvendo runApp.
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previous?.call(details);
      report(details.exception, details.stack, fatal: false);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, fatal: true);
      return true;
    };
  }

  void report(Object error, StackTrace? stack, {bool fatal = false}) {
    final stackStr = (stack ?? StackTrace.current).toString();
    unawaited(_api.postSilent('/v1/crashes', {
      'error_type': error.runtimeType.toString(),
      'message': error.toString(),
      'stack_trace': stackStr,
      'is_fatal': fatal,
      'breadcrumbs': List<String>.from(_telemetry.breadcrumbs),
      'platform': _telemetry.platform,
      'app_version': _telemetry.appVersion,
      if (_telemetry.deviceId != null) 'device_id': _telemetry.deviceId,
    }));
    if (kDebugMode) {
      // ignore: avoid_print
      print('[crash] $error');
    }
  }
}
