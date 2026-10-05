import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/boards_repository.dart';
import '../data/comments_repository.dart';
import '../data/notifications_repository.dart';
import '../data/pins_repository.dart';
import '../data/users_repository.dart';
import '../models/models.dart';
import 'auth.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

/// Shared HTTP client. The token and the 401 handler are read lazily, so the
/// client never has to be rebuilt when the user logs in or out.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    token: () => ref.read(authProvider).token,
    onUnauthorized: () => ref.read(authProvider.notifier).handleUnauthorized(),
  );
});

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final usersRepositoryProvider = Provider((ref) => UsersRepository(ref.watch(apiClientProvider)));
final pinsRepositoryProvider = Provider((ref) => PinsRepository(ref.watch(apiClientProvider)));
final boardsRepositoryProvider = Provider((ref) => BoardsRepository(ref.watch(apiClientProvider)));
final commentsRepositoryProvider = Provider((ref) => CommentsRepository(ref.watch(apiClientProvider)));
final notificationsRepositoryProvider =
    Provider((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

/// Categories rarely change: load once and keep.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(pinsRepositoryProvider).categories();
});

/// Set to false in widget tests so no network images are requested.
final networkImagesProvider = Provider<bool>((ref) => true);
