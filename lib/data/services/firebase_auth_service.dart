import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../l10n/loc.dart';
import 'auth_service.dart';

/// Log de auth — só em debug (não vaza uid/email em release).
void _authLog(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Erro de autenticação amigável (já traduzido para o usuário).
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Implementação real de [AuthService] usando Firebase Auth.
///
/// Provedores:
///  - Google  → iOS e Android
///  - Apple   → somente iOS (regra de negócio + exigência da Apple)
///
/// Devolve o ID token do Firebase em [idToken]; o backend valida esse token
/// contra o JWKS do projeto `stitchmind-b7721`. É um [ChangeNotifier] para o
/// router reagir a login/logout via `refreshListenable`.
class FirebaseAuthService extends ChangeNotifier implements AuthService {
  FirebaseAuthService._(this._auth) {
    _sub = _auth.authStateChanges().listen((u) {
      _authLog(u == null
          ? 'SM_AUTH: estado -> deslogado'
          : 'SM_AUTH: estado -> LOGADO uid=${u.uid} provedor=${u.providerData.map((p) => p.providerId).join(",")}');
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  late final Stream<User?> _userChanges = _auth.authStateChanges();

  // `serverClientId` (web OAuth client) é necessário no Android para que o
  // Google devolva um idToken válido para o Firebase. No iOS o client é lido
  // do GoogleService-Info.plist automaticamente.
  static const _webClientId =
      '39668973976-9eckjf24ucek6ig0plapk51p2mpe5heh.apps.googleusercontent.com';

  late final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: defaultTargetPlatform == TargetPlatform.android
        ? _webClientId
        : null,
  );

  late final dynamic _sub;

  static FirebaseAuthService create() => FirebaseAuthService._(FirebaseAuth.instance);

  // ─── AuthService ──────────────────────────────────────────────────
  @override
  Future<String?> idToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  bool get isSignedIn => _auth.currentUser != null;

  // ─── Estado reativo ───────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  Stream<User?> get userChanges => _userChanges;

  String? get displayName => _auth.currentUser?.displayName;
  String? get email => _auth.currentUser?.email;
  String? get photoUrl => _auth.currentUser?.photoURL;

  // ─── Edição de perfil ─────────────────────────────────────────────
  /// Atualiza o nome de exibição no Firebase e notifica ouvintes.
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await user.reload();
    notifyListeners();
  }

  /// Atualiza a URL da foto no Firebase e notifica ouvintes.
  Future<void> updatePhotoUrl(String url) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updatePhotoURL(url);
    await user.reload();
    notifyListeners();
  }

  // ─── Login: Google ────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    try {
      _authLog('SM_AUTH: google -> abrindo seletor de conta');
      final account = await _google.signIn();
      if (account == null) {
        _authLog('SM_AUTH: google -> cancelado pelo usuário');
        return; // usuário cancelou
      }
      final googleAuth = await account.authentication;
      _authLog(
          'SM_AUTH: google -> idToken=${googleAuth.idToken != null ? "ok" : "null"}');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      _authLog('SM_AUTH: google -> signInWithCredential OK');
    } on FirebaseAuthException catch (e) {
      _authLog('SM_AUTH: google ERRO firebase code=${e.code} msg=${e.message}');
      throw AuthFailure(_mapFirebase(e));
    } catch (e) {
      _authLog('SM_AUTH: google ERRO $e');
      throw AuthFailure(tr2('Could not sign in with Google. Please try again.', 'Não foi possível entrar com Google. Tente novamente.'));
    }
  }

  // ─── Login: Apple (somente iOS) ───────────────────────────────────
  Future<void> signInWithApple() async {
    try {
      _authLog('SM_AUTH: apple -> abrindo Sign in with Apple');
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      _authLog(
          'SM_AUTH: apple -> credencial recebida idToken=${appleCredential.identityToken != null ? "ok" : "null"}');

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      _authLog('SM_AUTH: apple -> signInWithCredential OK');

      // A Apple só manda o nome no PRIMEIRO login — persistimos no perfil.
      final given = appleCredential.givenName;
      final family = appleCredential.familyName;
      if (result.user != null &&
          (result.user!.displayName == null ||
              result.user!.displayName!.isEmpty) &&
          (given != null || family != null)) {
        final name = [given, family].whereType<String>().join(' ').trim();
        if (name.isNotEmpty) await result.user!.updateDisplayName(name);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _authLog('SM_AUTH: apple -> cancelado pelo usuário');
        return; // cancelou
      }
      _authLog('SM_AUTH: apple ERRO authorization code=${e.code} msg=${e.message}');
      throw AuthFailure(tr2('Could not sign in with Apple. Please try again.', 'Não foi possível entrar com Apple. Tente novamente.'));
    } on FirebaseAuthException catch (e) {
      _authLog('SM_AUTH: apple ERRO firebase code=${e.code} msg=${e.message}');
      throw AuthFailure(_mapFirebase(e));
    } catch (e) {
      _authLog('SM_AUTH: apple ERRO $e');
      throw AuthFailure(tr2('Could not sign in with Apple. Please try again.', 'Não foi possível entrar com Apple. Tente novamente.'));
    }
  }

  // ─── Reautenticação (exigida antes de operações sensíveis) ────────
  Future<void> _reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('apple.com') &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
      await user.reauthenticateWithCredential(
        OAuthProvider('apple.com').credential(
          idToken: apple.identityToken,
          rawNonce: rawNonce,
          accessToken: apple.authorizationCode,
        ),
      );
    } else {
      final account = await _google.signIn();
      if (account == null) throw AuthFailure(tr2('Re-authentication cancelled.', 'Reautenticação cancelada.'));
      final googleAuth = await account.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
    }
  }

  /// Exclui o usuário do Firebase. Reautentica e tenta de novo se o Firebase
  /// exigir login recente. Os dados de aplicação devem ser apagados ANTES
  /// (enquanto o token ainda é válido), via backend.
  Future<void> deleteFirebaseUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
      _authLog('SM_AUTH: conta -> excluída do Firebase');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _authLog('SM_AUTH: conta -> reautenticando para excluir');
        await _reauthenticate();
        await _auth.currentUser?.delete();
        _authLog('SM_AUTH: conta -> excluída do Firebase (pós-reauth)');
      } else {
        throw AuthFailure(_mapFirebase(e));
      }
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  String _mapFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return tr2('This email already has an account with another method. Sign in with the method you used before (Google or Apple).', 'Esse e-mail já tem conta com outro método. Entre com o método que você usou antes (Google ou Apple).');
      case 'invalid-credential':
        return tr2('Invalid or expired credential. Please try again.', 'Credencial inválida ou expirada. Tente novamente.');
      case 'network-request-failed':
        return tr2('No connection. Check your internet and try again.', 'Sem conexão. Verifique sua internet e tente de novo.');
      case 'operation-not-allowed':
        return tr2('This sign-in method is not enabled on the server.', 'Esse método de login não está habilitado no servidor.');
      default:
        return tr2('Sign-in failed (${e.code}). Please try again.', 'Falha no login (${e.code}). Tente novamente.');
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rnd = Random.secure();
    return List.generate(length, (_) => charset[rnd.nextInt(charset.length)])
        .join();
  }
}
