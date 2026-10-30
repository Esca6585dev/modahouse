import 'package:shared_preferences/shared_preferences.dart';

import '../data/users_repository.dart';

/// Remembers, per account, that the one-time "Näme bilen gyzyklanýarsyňyz?"
/// screen was already shown (picked or skipped), so it never comes back.
class InterestsPromptStore {
  const InterestsPromptStore();

  static String _key(int userId) => 'mh_interests_prompted_$userId';

  Future<bool> wasShown(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(userId)) ?? false;
    } catch (_) {
      return false; // No storage (tests): ask the server.
    }
  }

  Future<void> markShown(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId), true);
    } catch (_) {}
  }
}

/// True when the interests screen should be shown to [userId] now: it was
/// never shown on this device and the server says nothing was picked yet.
/// Errors (offline, old server without `/me/interests`) mean "don't ask".
Future<bool> shouldPromptInterests(
  UsersRepository users,
  int userId, {
  InterestsPromptStore store = const InterestsPromptStore(),
}) async {
  if (await store.wasShown(userId)) return false;
  try {
    final res = await users.interests();
    return !res.picked;
  } catch (_) {
    return false;
  }
}
