import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Key global do ScaffoldMessenger — usada para mostrar um aviso quando uma
/// push chega com o app em primeiro plano (Android). Ligada no MaterialApp.
final GlobalKey<ScaffoldMessengerState> pushMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Handler de mensagens em background/terminado. O SO já exibe a notificação;
/// aqui não precisamos fazer nada (precisa existir e ser top-level).
@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage message) async {}

/// Push notifications (FCM): pede permissão, registra o token no backend (com
/// país/região para segmentar) e mostra avisos em primeiro plano.
class PushService {
  PushService(this._api);
  final ApiClient _api;
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  /// País/região do aparelho (ex.: "BR", "US") a partir do locale do sistema.
  static String? deviceCountry() {
    try {
      final c = PlatformDispatcher.instance.locale.countryCode;
      if (c != null && c.isNotEmpty) return c.toUpperCase();
      for (final l in PlatformDispatcher.instance.locales) {
        final cc = l.countryCode;
        if (cc != null && cc.isNotEmpty) return cc.toUpperCase();
      }
    } catch (_) {}
    return null;
  }

  Future<void> init() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);

      final settings = await _fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('SM_PUSH: permissão = ${settings.authorizationStatus}');
      }

      // iOS: exibe banner/som mesmo com o app aberto.
      await _fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS precisa do APNs token antes de pedir o token do FCM.
      if (Platform.isIOS) {
        await _fm.getAPNSToken();
      }

      final token = await _fm.getToken();
      await _register(token);
      _fm.onTokenRefresh.listen(_register);

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    } catch (e) {
      if (kDebugMode) debugPrint('SM_PUSH: init falhou: $e');
    }
  }

  /// Atualiza o device (criado pela telemetria) com o push_token + país.
  Future<void> _register(String? token) async {
    if (token == null || token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('telemetry_device_id');
    final country = deviceCountry();
    await _api.postSilentJson('/v1/devices/register', {
      if (deviceId != null) 'device_id': deviceId,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'push_token': token,
      if (country != null) 'country': country,
    });
    if (kDebugMode) debugPrint('SM_PUSH: token registrado (country=$country)');
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final messenger = pushMessengerKey.currentState;
    final text = [n.title, n.body].where((s) => (s ?? '').isNotEmpty).join('\n');
    if (text.isEmpty) return;
    messenger?.showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }
}
