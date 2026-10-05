import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/models.dart';
import 'providers.dart';

class AuthState {
  const AuthState({this.user, this.token, this.ready = false});

  final Me? user;
  final String? token;

  /// False until the stored token has been checked at startup.
  final bool ready;

  bool get isLoggedIn => user != null && token != null;
}

/// Called when the server rejects our token (set up by the router).
typedef UnauthorizedListener = void Function();

class AuthNotifier extends Notifier<AuthState> {
  UnauthorizedListener? onSessionExpired;

  @override
  AuthState build() {
    unawaited(Future.microtask(_restore));
    return const AuthState();
  }

  Future<void> _restore() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.read();
    if (token == null || token.isEmpty) {
      state = const AuthState(ready: true);
      return;
    }
    // Make the token available to the interceptor before calling /auth/me.
    state = AuthState(token: token);
    try {
      final me = await ref.read(authRepositoryProvider).me();
      state = AuthState(user: me, token: token, ready: true);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await storage.clear();
      // On network errors keep the token for the next launch.
      state = const AuthState(ready: true);
    }
  }

  Future<void> login(String login, String password) async {
    final res = await ref.read(authRepositoryProvider).login(login.trim(), password);
    await _signIn(res);
  }

  Future<void> register({
    required String username,
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await ref.read(authRepositoryProvider).register(
          username: username.trim(),
          name: name.trim(),
          email: email.trim(),
          password: password,
        );
    await _signIn(res);
  }

  Future<void> _signIn(AuthResponse res) async {
    await ref.read(tokenStorageProvider).write(res.token);
    state = AuthState(user: res.user, token: res.token, ready: true);
  }

  /// Changes the password and stores the new token the server returns
  /// (all older tokens stop working).
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await ref.read(authRepositoryProvider).changePassword(currentPassword, newPassword);
    if (res != null && res.token.isNotEmpty) await _signIn(res);
  }

  /// Replaces the cached user after profile edits.
  void setUser(Me me) {
    if (state.token == null) return;
    state = AuthState(user: me, token: state.token, ready: true);
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AuthState(ready: true);
  }

  /// A request with our token got 401: the token is invalid or expired.
  void handleUnauthorized() {
    if (state.token == null) return;
    final wasReady = state.ready;
    unawaited(ref.read(tokenStorageProvider).clear());
    state = const AuthState(ready: true);
    // At startup an expired token simply means "logged out".
    if (wasReady) onSessionExpired?.call();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// The logged-in user's id (null when logged out). Handy for `select`-style watches.
final currentUserIdProvider = Provider<int?>((ref) => ref.watch(authProvider).user?.id);
