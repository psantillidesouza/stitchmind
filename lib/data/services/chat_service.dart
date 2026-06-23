import 'api_client.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  const ChatMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ChatService {
  ChatService(this._api);
  final ApiClient _api;

  /// Envia o histórico e retorna a resposta da IA.
  Future<String> send(List<ChatMessage> history) async {
    final json = await _api.post('/v1/chat', {
      'messages': history.map((m) => m.toJson()).toList(),
    }) as Map<String, dynamic>;
    return (json['reply'] as String?) ?? 'Sem resposta.';
  }
}
