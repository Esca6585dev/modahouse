import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../core/server_config.dart';
import '../l10n/strings.dart';
import 'auth.dart';

class ServerState {
  const ServerState({
    required this.apiUrl,
    required this.webUrl,
    required this.source,
    this.busy = false,
    this.lastCheck,
    this.reachable,
  });

  /// Current server origin (same as [AppConfig.apiUrl]).
  final String apiUrl;

  /// Current web address for shared links (same as [AppConfig.webUrl]).
  final String webUrl;
  final ServerSource source;

  /// A check or refresh is running.
  final bool busy;

  /// When the last refresh finished (null = not yet in this session).
  final DateTime? lastCheck;

  /// Result of the last refresh: did any server answer? Null = not checked.
  final bool? reachable;

  ServerState copyWith({
    String? apiUrl,
    String? webUrl,
    ServerSource? source,
    bool? busy,
    DateTime? lastCheck,
    bool? reachable,
  }) => ServerState(
    apiUrl: apiUrl ?? this.apiUrl,
    webUrl: webUrl ?? this.webUrl,
    source: source ?? this.source,
    busy: busy ?? this.busy,
    lastCheck: lastCheck ?? this.lastCheck,
    reachable: reachable ?? this.reachable,
  );
}

/// What [ServerNotifier.refresh] did.
enum RefreshResult { unchanged, switched, unreachable, skipped }

final serverStoreProvider = Provider<ServerStore>((ref) => PrefsServerStore());
final serverProbeProvider = Provider<ServerProbe>((ref) => ServerProbe());

/// Source of the address loaded before `runApp` (overridden in `main`).
final initialServerSourceProvider = Provider<ServerSource>(
  (ref) => ServerSource.build,
);

/// The current server address and the logic that changes it.
///
/// Everything that talks to the server reads [AppConfig.apiUrl] at request
/// time, and [apiClientProvider] watches [ServerState.apiUrl], so a switch
/// rebuilds the repositories and every provider that watches them.
class ServerNotifier extends Notifier<ServerState> {
  /// Refreshes on app resume happen at most this often.
  static const resumeInterval = Duration(minutes: 10);

  Future<RefreshResult>? _running;

  @override
  ServerState build() => ServerState(
    apiUrl: AppConfig.apiUrl,
    webUrl: AppConfig.webUrl,
    source: ref.read(initialServerSourceProvider),
  );

  ServerProbe get _probe => ref.read(serverProbeProvider);
  ServerStore get _store => ref.read(serverStoreProvider);

  /// Runs the config refresh from docs/API.md. With [force] false it is
  /// skipped when the last refresh was less than [resumeInterval] ago.
  Future<RefreshResult> refresh({bool force = true}) {
    final last = state.lastCheck;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < resumeInterval) {
      return Future.value(RefreshResult.skipped);
    }
    return _running ??= _refresh().whenComplete(() => _running = null);
  }

  Future<RefreshResult> _refresh() async {
    state = state.copyWith(busy: true);
    try {
      final r = await resolveServer(
        probe: _probe,
        current: state.apiUrl,
        currentSource: state.source,
        buildDefault: AppConfig.defaultApiUrl,
        configUrl: AppConfig.configUrl,
      );
      if (!ref.mounted) return RefreshResult.skipped;
      final switched = r.apiUrl != state.apiUrl;
      if (switched || r.webUrl != null) {
        await _apply(
          apiUrl: r.apiUrl,
          source: r.source,
          webUrl: r.webUrl ?? _savedWeb,
        );
      }
      if (!ref.mounted) return RefreshResult.skipped;
      state = state.copyWith(reachable: r.reachable, lastCheck: DateTime.now());
      if (!r.reachable) return RefreshResult.unreachable;
      return switched ? RefreshResult.switched : RefreshResult.unchanged;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// The web address as stored ("" when it is the build default).
  String get _savedWeb =>
      state.webUrl == AppConfig.defaultWebUrl ? '' : state.webUrl;

  /// Checks a typed address and switches to it. Returns null on success,
  /// otherwise a Turkmen error message.
  Future<String?> setManual(String raw) async {
    if (raw.trim().isEmpty) return S.serverUrlRequired;
    final url = normalizeServerUrl(raw);
    if (url == null) return S.serverUrlInvalid;
    state = state.copyWith(busy: true);
    try {
      final ok = await _probe.health(url);
      if (!ref.mounted) return null;
      if (!ok) return S.serverUnreachable;
      final cfg = await _probe.config(url);
      if (!ref.mounted) return null;
      await _apply(
        apiUrl: url,
        source: ServerSource.manual,
        webUrl: cfg == null
            ? _savedWeb
            : normalizeServerUrl(cfg.webUrl, stripApi: false) ?? '',
        force: true,
      );
      state = state.copyWith(reachable: true, lastCheck: DateTime.now());
      return null;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// Goes back to the build-time `API_URL` and forgets the saved address.
  Future<void> resetToDefault() async {
    state = state.copyWith(busy: true);
    try {
      final changed = state.apiUrl != AppConfig.defaultApiUrl;
      AppConfig.resetToDefaults();
      await _store.clear();
      if (!ref.mounted) return;
      state = ServerState(
        apiUrl: AppConfig.apiUrl,
        webUrl: AppConfig.webUrl,
        source: ServerSource.build,
        busy: true,
      );
      if (changed) _afterSwitch();
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> _apply({
    required String apiUrl,
    required ServerSource source,
    required String webUrl,
    bool force = false,
  }) async {
    final changed = apiUrl != state.apiUrl;
    AppConfig.use(apiUrl: apiUrl, webUrl: webUrl);
    // Following the server while on the build default keeps it "default".
    final src = !force && !changed ? state.source : source;
    if (!changed && !force && webUrl == _savedWeb) return;
    await _store.write(
      SavedServer(apiUrl: AppConfig.apiUrl, source: src, webUrl: webUrl),
    );
    if (!ref.mounted) return;
    state = state.copyWith(
      apiUrl: AppConfig.apiUrl,
      webUrl: AppConfig.webUrl,
      source: src,
    );
    if (changed) _afterSwitch();
  }

  /// The token may not be valid on the new server: check it again.
  void _afterSwitch() {
    if (!ref.exists(authProvider)) return; // Not started yet: nothing to check.
    unawaited(ref.read(authProvider.notifier).revalidate());
  }
}

final serverProvider = NotifierProvider<ServerNotifier, ServerState>(
  ServerNotifier.new,
);
