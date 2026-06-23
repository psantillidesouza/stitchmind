/// Abstração de autenticação.
///
/// Implementada por [FirebaseAuthService] (Google em iOS/Android, Apple no
/// iOS). O resto do app depende só desta interface — nunca da implementação.
abstract class AuthService {
  /// Token a ser enviado em `Authorization: Bearer <token>`. Null se deslogado.
  Future<String?> idToken();

  /// Identificador estável do usuário/conta atual.
  String? get uid;

  bool get isSignedIn;
}
