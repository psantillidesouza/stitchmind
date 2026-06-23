import 'dart:io';

import 'api_client.dart';
import 'firebase_auth_service.dart';

/// Edição do perfil do usuário: nome e foto.
///
/// Fonte da verdade é o backend (Postgres + MinIO), mas também espelhamos no
/// Firebase para que o app — que lê displayName/photoURL do Firebase — reflita
/// a mudança na hora e o token fique consistente.
class ProfileService {
  ProfileService(this._api, this._auth);

  final ApiClient _api;
  final FirebaseAuthService _auth;

  /// Renomeia o usuário. Persiste no backend e espelha no Firebase.
  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _api.patch('/v1/auth/me', {'name': trimmed});
    await _auth.updateDisplayName(trimmed);
  }

  /// Sobe a foto (já convertida em WebP) para o backend e devolve a URL pública.
  Future<String> uploadAvatar(File image) async {
    final json = await _api.postFile('/v1/auth/avatar', image.path, field: 'image');
    final url = (json is Map && json['photo_url'] is String)
        ? json['photo_url'] as String
        : null;
    if (url == null) {
      throw Exception('Resposta sem photo_url ao subir avatar.');
    }
    await _auth.updatePhotoUrl(url);
    return url;
  }
}
