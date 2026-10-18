import '../l10n/strings.dart';
import '../models/models.dart';

String _two(int v) => v.toString().padLeft(2, '0');

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "14:05" in local time.
String clockTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// Compact relative time for the chat list: "şu wagt", "5 min", "2 sag",
/// "Düýn", "3 gün", then the date.
String chatTime(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final n = (now ?? DateTime.now()).toLocal();
  final l = d.toLocal();
  final diff = n.difference(l);
  if (diff.inMinutes < 1) return S.justNow;
  if (diff.inMinutes < 60) return S.minutesShort(diff.inMinutes);
  final days = _day(n).difference(_day(l)).inDays;
  if (days == 0) return S.hoursShort(diff.inHours.clamp(1, 23));
  if (days == 1) return S.yesterdayDay;
  if (days < 7) return S.daysShort(days);
  return '${_two(l.day)}.${_two(l.month)}.${l.year}';
}

/// Date separator in a conversation: "Şu gün", "Düýn", "12 oktýabr",
/// "3 mart 2025".
String dayLabel(DateTime d, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final l = d.toLocal();
  final days = _day(n).difference(_day(l)).inDays;
  if (days == 0) return S.today;
  if (days == 1) return S.yesterdayDay;
  final month = S.months[l.month - 1];
  return l.year == n.year ? '${l.day} $month' : '${l.day} $month ${l.year}';
}

/// "820 KB", "1,4 MB".
String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// The one-line preview of a message: "📷 Surat", "📎 name", "🔗 Post",
/// "Bu habar pozuldy", with "Siz: …" for my own messages.
String messagePreview(Message m, {bool you = true}) {
  String body;
  if (m.deleted) {
    return S.messageDeleted;
  }
  switch (m.kind) {
    case MessageKind.image:
      final video = m.attachment?.isVideo ?? false;
      body = video ? S.videoPreview : S.photoPreview;
      if (m.text.isNotEmpty) body = '$body · ${m.text}';
    case MessageKind.file:
      body = (m.attachment?.isVideo ?? false)
          ? S.videoPreview
          : S.filePreview(m.attachment?.name ?? S.fileLabel);
    case MessageKind.pin:
      body = m.text.isNotEmpty ? '${S.postPreview} · ${m.text}' : S.postPreview;
    case MessageKind.text:
      body = m.text;
  }
  body = body.replaceAll('\n', ' ');
  return you && m.mine ? S.youPrefix(body) : body;
}
