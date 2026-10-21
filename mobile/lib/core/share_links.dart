import '../config.dart';
import '../models/models.dart';

/// The text that goes with a shared post: its title and the web link.
String pinShareText(Pin pin) => [
  pin.title.trim(),
  AppConfig.pinLink(pin.id),
].where((e) => e.isNotEmpty).join('\n');

/// `https://wa.me/?text=<title + link>`: opens WhatsApp with the message typed.
Uri whatsappShareUri(String link, {String text = ''}) {
  final body = [text.trim(), link].where((e) => e.isNotEmpty).join('\n');
  return Uri.parse('https://wa.me/?text=${Uri.encodeComponent(body)}');
}

/// `https://t.me/share/url?url=<link>&text=<title>`: Telegram's share dialog.
Uri telegramShareUri(String link, {String text = ''}) {
  final t = text.trim();
  return Uri.parse(
    'https://t.me/share/url?url=${Uri.encodeComponent(link)}'
    '${t.isEmpty ? '' : '&text=${Uri.encodeComponent(t)}'}',
  );
}

/// File name for a downloaded media item: `modahouse-<id>-<index>.<ext>`
/// (the same name the server sends in `Content-Disposition`).
String pinDownloadFileName(int id, int index, String mimeType) {
  final mime = mimeType.split(';').first.trim().toLowerCase();
  final ext = switch (mime) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    'video/mp4' => 'mp4',
    'video/webm' => 'webm',
    'video/quicktime' => 'mov',
    _ => mime.startsWith('video/') ? 'mp4' : 'jpg',
  };
  return 'modahouse-$id-$index.$ext';
}

/// File name of a post's share card.
String pinShareCardFileName(int id) => 'modahouse-$id-card.jpg';
