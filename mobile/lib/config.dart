/// Server addresses and other app-wide configuration.
///
/// The API address is no longer fixed at build time. The build only sets the
/// *default* (`--dart-define=API_URL=https://api.example.tm`); at runtime the
/// app follows the address the admin sets in the admin panel (`GET /api/config`)
/// or one the user typed under Sazlamalar → Serwer. See `core/server_config.dart`.
///
/// The default `10.0.2.2` is how the Android emulator reaches the host machine.
class AppConfig {
  AppConfig._();

  static const String _rawApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String _rawWebUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'https://modahouse.tm',
  );

  static const String _rawConfigUrl = String.fromEnvironment('CONFIG_URL');

  /// Build-time default server origin (`API_URL`), normalised.
  static final String defaultApiUrl =
      normalizeServerUrl(_rawApiUrl) ?? _trimSlash(_rawApiUrl.trim());

  /// Build-time default web address (`WEB_URL`), normalised.
  static final String defaultWebUrl =
      normalizeServerUrl(_rawWebUrl, stripApi: false) ??
      _trimSlash(_rawWebUrl.trim());

  /// Optional JSON file with the `AppConfig` shape (`CONFIG_URL`), used only
  /// when no server answers. Null when not set or invalid.
  static final String? configUrl = _rawConfigUrl.trim().isEmpty
      ? null
      : _validHttp(_rawConfigUrl.trim());

  static String _apiUrl = defaultApiUrl;
  static String _webUrl = defaultWebUrl;

  /// Current server origin without a trailing slash, e.g. `http://10.0.2.2:8080`.
  /// Changes at runtime (see [use]); always read it, never cache it.
  static String get apiUrl => _apiUrl;

  /// Base URL of the REST API on the current server.
  static String get apiBase => '$_apiUrl/api';

  /// Public web address used in shared / copied links: from the server
  /// config, otherwise `--dart-define=WEB_URL=https://modahouse.tm`.
  static String get webUrl => _webUrl;

  /// Switches the addresses every request, image and link uses from now on.
  /// Empty or invalid values are ignored (an empty web address means the
  /// build default).
  static void use({String? apiUrl, String? webUrl}) {
    if (apiUrl != null) {
      final a = normalizeServerUrl(apiUrl);
      if (a != null) _apiUrl = a;
    }
    if (webUrl != null) {
      _webUrl = normalizeServerUrl(webUrl, stripApi: false) ?? defaultWebUrl;
    }
  }

  /// Back to the build-time defaults (tests, "Başlangyç salga").
  static void resetToDefaults() {
    _apiUrl = defaultApiUrl;
    _webUrl = defaultWebUrl;
  }

  /// Link to a post on the web.
  static String pinLink(int id) => '$webUrl/pin/$id';

  /// The web admin panel.
  static String get adminLink => '$webUrl/admin';

  /// Default page size for paginated lists.
  static const int pageSize = 24;
}

String _trimSlash(String s) {
  var out = s;
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

String? _validHttp(String s) {
  final uri = Uri.tryParse(s);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) return null;
  return s;
}

/// Normalises a server address typed by a person or set in the admin panel:
/// trims spaces, drops trailing slashes and a trailing `/api` (unless
/// [stripApi] is false) and requires an absolute `http(s)://` URL with a host.
/// Returns null when the address is not usable.
///
/// `" https://Api.Example.tm/api/ "` → `"https://api.example.tm"`.
String? normalizeServerUrl(String? raw, {bool stripApi = true}) {
  if (raw == null) return null;
  var s = _trimSlash(raw.trim());
  if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
  if (stripApi && s.toLowerCase().endsWith('/api')) {
    s = _trimSlash(s.substring(0, s.length - 4));
  }
  final uri = Uri.tryParse(s);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.isEmpty || uri.hasQuery || uri.hasFragment) return null;
  if (uri.userInfo.isNotEmpty) return null;
  final port = uri.hasPort ? ':${uri.port}' : '';
  final path = _trimSlash(uri.path);
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return '$scheme://${host.toLowerCase()}$port$path';
}

/// Turns a relative image path from the API (`/uploads/...`) into an absolute URL
/// on the current server ([origin] overrides it). Absolute URLs are returned
/// unchanged and an empty path stays empty.
String resolveImageUrl(String path, {String? origin}) {
  final p = path.trim();
  if (p.isEmpty) return '';
  if (p.startsWith('http://') ||
      p.startsWith('https://') ||
      p.startsWith('data:')) {
    return p;
  }
  final base = origin ?? AppConfig.apiUrl;
  return p.startsWith('/') ? '$base$p' : '$base/$p';
}

/// True when the URL points to an SVG file (seed images are SVG).
bool isSvgUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return path.toLowerCase().endsWith('.svg');
}
