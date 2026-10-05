import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthResponse> login(String login, String password) async =>
      AuthResponse.fromJson(
        parseJson(
          await _api.post(
            '/auth/login',
            data: {'login': login, 'password': password},
          ),
        ),
      );

  Future<AuthResponse> register({
    required String username,
    required String name,
    required String email,
    required String password,
  }) async => AuthResponse.fromJson(
    parseJson(
      await _api.post(
        '/auth/register',
        data: {
          'username': username,
          'name': name,
          'email': email,
          'password': password,
        },
      ),
    ),
  );

  /// Current user. `GET /me` is an alias of `/auth/me` that is not rate-limited.
  Future<Me> me() async => Me.fromJson(parseJson(await _api.get('/me')));

  Future<Me> updateMe({String? name, String? bio, String? username}) async {
    final body = <String, Object?>{
      'name': ?name,
      'bio': ?bio,
      'username': ?username,
    };
    return Me.fromJson(parseJson(await _api.put('/me', data: body)));
  }

  /// Changing the password invalidates all older tokens, so the server returns
  /// a fresh `{token, user}` that must replace the stored token.
  /// Returns null if an older server answers 204 without a body.
  Future<AuthResponse?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final data = await _api.put(
      '/me/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    if (data is Map && data['token'] is String) {
      return AuthResponse.fromJson(parseJson(data));
    }
    return null;
  }

  Future<Me> uploadAvatar(PickedImage image) async => Me.fromJson(
    parseJson(
      await _api.post(
        '/me/avatar',
        data: FormData.fromMap({'avatar': image.toMultipart()}),
      ),
    ),
  );

  Future<Me> deleteAvatar() async =>
      Me.fromJson(parseJson(await _api.delete('/me/avatar')));
}
