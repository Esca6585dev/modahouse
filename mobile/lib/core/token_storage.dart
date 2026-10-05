import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the JWT lives between app launches.
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Default storage: Android Keystore backed (WebCrypto + localStorage on web).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'mh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Storage unavailable: the session only lasts until the app closes.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

/// In-memory storage for tests.
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}
