import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Where the current server address came from.
enum ServerSource {
  /// The build-time `API_URL`.
  build,

  /// The admin panel (`GET /api/config`) or the `CONFIG_URL` file.
  remote,

  /// Typed by the user under Sazlamalar → Serwer.
  manual,
}

/// `GET /api/config` (and the optional `CONFIG_URL` file).
class RemoteAppConfig {
  const RemoteAppConfig({
    this.apiUrl = '',
    this.webUrl = '',
    this.registrationOpen = true,
    this.updatedAt = '',
  });

  factory RemoteAppConfig.fromJson(Map<dynamic, dynamic> j) => RemoteAppConfig(
    apiUrl: j['apiUrl'] is String ? (j['apiUrl'] as String).trim() : '',
    webUrl: j['webUrl'] is String ? (j['webUrl'] as String).trim() : '',
    registrationOpen: j['registrationOpen'] is bool
        ? j['registrationOpen'] as bool
        : true,
    updatedAt: j['updatedAt'] is String ? j['updatedAt'] as String : '',
  );

  /// Public server origin; "" = keep the current one.
  final String apiUrl;

  /// Public web address for shared links; "" = client default.
  final String webUrl;
  final bool registrationOpen;
  final String updatedAt;
}

/// The address the app saved last time.
class SavedServer {
  const SavedServer({
    required this.apiUrl,
    this.source = ServerSource.remote,
    this.webUrl = '',
  });

  final String apiUrl;
  final ServerSource source;

  /// "" = unknown (use the build default).
  final String webUrl;
}

/// Persists the chosen server between launches.
abstract class ServerStore {
  Future<SavedServer?> read();
  Future<void> write(SavedServer server);
  Future<void> clear();
}

/// [ServerStore] on top of shared_preferences (localStorage on the web).
class PrefsServerStore implements ServerStore {
  static const _apiKey = 'mh_server_api_url';
  static const _sourceKey = 'mh_server_source';
  static const _webKey = 'mh_server_web_url';

  @override
  Future<SavedServer?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final api = normalizeServerUrl(prefs.getString(_apiKey));
      if (api == null) return null;
      final source = ServerSource.values
          .where((s) => s.name == prefs.getString(_sourceKey))
          .firstOrNull;
      return SavedServer(
        apiUrl: api,
        source: source ?? ServerSource.remote,
        webUrl: prefs.getString(_webKey) ?? '',
      );
    } catch (_) {
      return null; // No storage (tests, private mode): use the defaults.
    }
  }

  @override
  Future<void> write(SavedServer server) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKey, server.apiUrl);
      await prefs.setString(_sourceKey, server.source.name);
      await prefs.setString(_webKey, server.webUrl);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKey);
      await prefs.remove(_sourceKey);
      await prefs.remove(_webKey);
    } catch (_) {}
  }
}

/// In-memory [ServerStore] for tests.
class MemoryServerStore implements ServerStore {
  MemoryServerStore([this.saved]);

  SavedServer? saved;

  @override
  Future<SavedServer?> read() async => saved;

  @override
  Future<void> write(SavedServer server) async => saved = server;

  @override
  Future<void> clear() async => saved = null;
}

/// Reads the saved address and makes it current. Called before `runApp`, so
/// the very first request already goes to the right server.
Future<ServerSource> loadSavedServer(ServerStore store) async {
  final saved = await store.read();
  if (saved == null) return ServerSource.build;
  AppConfig.use(
    apiUrl: saved.apiUrl,
    webUrl: saved.webUrl.isEmpty ? null : saved.webUrl,
  );
  return saved.source;
}

/// The small HTTP layer used to check servers. Short timeouts; never throws.
class ServerProbe {
  ServerProbe({Dio? dio, this.timeout = const Duration(seconds: 6)})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: timeout,
              receiveTimeout: timeout,
              headers: {'Accept': 'application/json'},
            ),
          );

  final Dio dio;
  final Duration timeout;

  Future<Object?> _getJson(String url) async {
    final res = await dio
        .get<dynamic>(url, options: Options(responseType: ResponseType.plain))
        .timeout(timeout + const Duration(seconds: 1));
    if ((res.statusCode ?? 0) != 200) return null;
    final body = res.data;
    if (body is String) return body.trim().isEmpty ? null : jsonDecode(body);
    return body;
  }

  /// True when `{origin}/api/health` answers `{"status":"ok"}`.
  Future<bool> health(String origin) async {
    try {
      final data = await _getJson('$origin/api/health');
      return data is Map && data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// `GET {origin}/api/config`, or null when it fails for any reason.
  Future<RemoteAppConfig?> config(String origin) =>
      configFile('$origin/api/config');

  /// A JSON document with the `AppConfig` shape (also the `CONFIG_URL` file).
  Future<RemoteAppConfig?> configFile(String url) async {
    try {
      final data = await _getJson(url);
      return data is Map ? RemoteAppConfig.fromJson(data) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Result of [resolveServer].
class ServerResolution {
  const ServerResolution({
    required this.apiUrl,
    required this.source,
    required this.reachable,
    this.webUrl,
    this.config,
  });

  /// The address to use from now on (may equal the current one).
  final String apiUrl;
  final ServerSource source;

  /// False when no server answered: [apiUrl] is then the unchanged current one.
  final bool reachable;

  /// Web address for shared links ("" = build default), null = unknown.
  final String? webUrl;

  /// The config that decided it, if any.
  final RemoteAppConfig? config;
}

/// The client algorithm from docs/API.md ("How the Android app uses it"):
///
/// 1. `GET {current}/api/config`;
/// 2. when `apiUrl` is set and differs, switch only if `{apiUrl}/api/health`
///    answers `{"status":"ok"}` (a typo in the admin panel never strands apps);
/// 3. when the current server is unreachable, try the build-time default,
///    then the optional `CONFIG_URL` file, and repeat step 2 for each.
Future<ServerResolution> resolveServer({
  required ServerProbe probe,
  required String current,
  required ServerSource currentSource,
  required String buildDefault,
  String? configUrl,
}) async {
  Future<ServerResolution> follow(
    String base,
    ServerSource baseSource,
    RemoteAppConfig cfg,
  ) async {
    final target = normalizeServerUrl(cfg.apiUrl);
    final web = normalizeServerUrl(cfg.webUrl, stripApi: false) ?? '';
    if (target != null && target != base && await probe.health(target)) {
      return ServerResolution(
        apiUrl: target,
        source: ServerSource.remote,
        reachable: true,
        webUrl: web,
        config: cfg,
      );
    }
    return ServerResolution(
      apiUrl: base,
      source: baseSource,
      reachable: true,
      webUrl: web,
      config: cfg,
    );
  }

  // 1–2: the current server.
  final cfg = await probe.config(current);
  if (cfg != null) return follow(current, currentSource, cfg);
  if (await probe.health(current)) {
    // Reachable, but too old to have /config: stay.
    return ServerResolution(
      apiUrl: current,
      source: currentSource,
      reachable: true,
    );
  }

  // 3a: the build-time default.
  if (buildDefault != current) {
    final def = await probe.config(buildDefault);
    if (def != null) return follow(buildDefault, ServerSource.build, def);
    if (await probe.health(buildDefault)) {
      return ServerResolution(
        apiUrl: buildDefault,
        source: ServerSource.build,
        reachable: true,
      );
    }
  }

  // 3b: the CONFIG_URL file (it is not a server itself).
  if (configUrl != null) {
    final file = await probe.configFile(configUrl);
    final target = normalizeServerUrl(file?.apiUrl);
    if (file != null && target != null && await probe.health(target)) {
      return ServerResolution(
        apiUrl: target,
        source: ServerSource.remote,
        reachable: true,
        webUrl: normalizeServerUrl(file.webUrl, stripApi: false) ?? '',
        config: file,
      );
    }
  }

  return ServerResolution(
    apiUrl: current,
    source: currentSource,
    reachable: false,
  );
}
