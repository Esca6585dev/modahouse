import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

/// `/chats` and `/messages` (docs/API.md, v6).
class ChatsRepository {
  ChatsRepository(this._api);
  final ApiClient _api;

  static const messagesLimit = 30;

  Future<Page<Chat>> list(int page, {int limit = 30}) async => Page.fromJson(
    parseJson(await _api.get('/chats', query: {'page': page, 'limit': limit})),
    Chat.fromJson,
  );

  /// Opens the chat with [username], creating it when needed.
  Future<Chat> open(String username) async => Chat.fromJson(
    parseJson(await _api.post('/chats', data: {'username': username})),
  );

  Future<Chat> get(int id) async =>
      Chat.fromJson(parseJson(await _api.get('/chats/$id')));

  /// The newest messages, or the ones before [before] (oldest → newest).
  Future<MessagePage> messages(
    int chatId, {
    int? before,
    int limit = messagesLimit,
  }) async => MessagePage.fromJson(
    parseJson(
      await _api.get(
        '/chats/$chatId/messages',
        query: {'before': before, 'limit': limit},
      ),
    ),
  );

  Future<Message> sendText(
    int chatId, {
    String text = '',
    int? pinId,
    String clientId = '',
  }) async => Message.fromJson(
    parseJson(
      await _api.post(
        '/chats/$chatId/messages',
        data: {
          'text': text,
          'pinId': ?pinId,
          if (clientId.isNotEmpty) 'clientId': clientId,
        },
      ),
    ),
  );

  Future<Message> sendFile(
    int chatId,
    OutgoingFile file, {
    String text = '',
    String clientId = '',
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: DioMediaType.parse(
          file.mimeType.contains('/')
              ? file.mimeType
              : 'application/octet-stream',
        ),
      ),
      if (text.isNotEmpty) 'text': text,
      if (clientId.isNotEmpty) 'clientId': clientId,
    });
    return Message.fromJson(
      parseJson(
        await _api.post(
          '/chats/$chatId/messages',
          data: form,
          onSendProgress: onProgress == null
              ? null
              : (sent, total) {
                  if (total > 0) onProgress(sent / total);
                },
        ),
      ),
    );
  }

  /// Everything up to [messageId] is read.
  Future<void> read(int chatId, int messageId) =>
      _api.post('/chats/$chatId/read', data: {'messageId': messageId});

  Future<void> typing(int chatId) => _api.post('/chats/$chatId/typing');

  Future<void> deleteMessage(int id) => _api.delete('/messages/$id');

  Future<int> unreadCount() async =>
      asInt(parseJson(await _api.get('/chats/unread-count'))['count']);
}
