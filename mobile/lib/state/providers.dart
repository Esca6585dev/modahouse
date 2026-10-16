import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../data/ai_repository.dart';
import '../data/auth_repository.dart';
import '../data/boards_repository.dart';
import '../data/business_repository.dart';
import '../data/cart_repository.dart';
import '../data/comments_repository.dart';
import '../data/notifications_repository.dart';
import '../data/orders_repository.dart';
import '../data/pins_repository.dart';
import '../data/reviews_repository.dart';
import '../data/stories_repository.dart';
import '../data/users_repository.dart';
import '../models/models.dart';
import 'auth.dart';
import 'server.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

/// Shared HTTP client. The token and the 401 handler are read lazily, so the
/// client never has to be rebuilt when the user logs in or out.
///
/// It is rebuilt when the server address changes, which rebuilds every
/// repository and reloads the providers that watch them. (Requests always go
/// to the current `AppConfig.apiUrl` anyway, even through an old instance.)
final apiClientProvider = Provider<ApiClient>((ref) {
  ref.watch(serverProvider.select((s) => s.apiUrl));
  return ApiClient(
    token: () => ref.read(authProvider).token,
    onUnauthorized: () => ref.read(authProvider.notifier).handleUnauthorized(),
  );
});

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
final usersRepositoryProvider = Provider(
  (ref) => UsersRepository(ref.watch(apiClientProvider)),
);
final pinsRepositoryProvider = Provider(
  (ref) => PinsRepository(ref.watch(apiClientProvider)),
);
final boardsRepositoryProvider = Provider(
  (ref) => BoardsRepository(ref.watch(apiClientProvider)),
);
final commentsRepositoryProvider = Provider(
  (ref) => CommentsRepository(ref.watch(apiClientProvider)),
);
final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);
final businessRepositoryProvider = Provider(
  (ref) => BusinessRepository(ref.watch(apiClientProvider)),
);
final reviewsRepositoryProvider = Provider(
  (ref) => ReviewsRepository(ref.watch(apiClientProvider)),
);
final cartRepositoryProvider = Provider(
  (ref) => CartRepository(ref.watch(apiClientProvider)),
);
final ordersRepositoryProvider = Provider(
  (ref) => OrdersRepository(ref.watch(apiClientProvider)),
);
final aiRepositoryProvider = Provider(
  (ref) => AiRepository(ref.watch(apiClientProvider)),
);
final storiesRepositoryProvider = Provider(
  (ref) => StoriesRepository(ref.watch(apiClientProvider)),
);

/// Categories rarely change: load once and keep.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(pinsRepositoryProvider).categories();
});

/// Business categories (`GET /business-categories`), with the built-in
/// list as a fallback while loading or offline.
final businessCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  try {
    final list = await ref.watch(businessRepositoryProvider).categories();
    if (list.isNotEmpty) return list;
  } catch (_) {}
  return [
    for (final e in businessCategoryNames.entries)
      Category(slug: e.key, name: e.value),
  ];
});

/// Set to false in widget tests so no network images are requested.
final networkImagesProvider = Provider<bool>((ref) => true);

/// A file fetched from the API (watermarked download, share card).
class FetchedMedia {
  const FetchedMedia(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

/// Fetches binary media by absolute URL (through the shared client, so the
/// token goes along). Overridden in widget tests.
typedef MediaLoader = Future<FetchedMedia> Function(String url);

final mediaLoaderProvider = Provider<MediaLoader>((ref) {
  final client = ref.watch(apiClientProvider);
  return (url) async {
    final res = await client.dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': '*/*'},
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final bytes = res.data ?? const <int>[];
    if (bytes.isEmpty) throw StateError('empty response');
    final type = (res.headers.value('content-type') ?? 'image/jpeg')
        .split(';')
        .first
        .trim();
    return FetchedMedia(Uint8List.fromList(bytes), type);
  };
});
