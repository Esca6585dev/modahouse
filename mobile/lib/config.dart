/// Build-time configuration.
///
/// Pass the backend address with `--dart-define=API_URL=http://192.168.1.10:8080`.
/// The default `10.0.2.2` is how the Android emulator reaches the host machine.
class AppConfig {
  AppConfig._();

  static const String _rawApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Server origin without a trailing slash, e.g. `http://10.0.2.2:8080`.
  static final String apiUrl = _rawApiUrl.endsWith('/')
      ? _rawApiUrl.substring(0, _rawApiUrl.length - 1)
      : _rawApiUrl;

  /// Base URL of the REST API.
  static String get apiBase => '$apiUrl/api';

  /// Default page size for paginated lists.
  static const int pageSize = 24;
}

/// Turns a relative image path from the API (`/uploads/...`) into an absolute URL.
/// Absolute URLs are returned unchanged and an empty path stays empty.
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
