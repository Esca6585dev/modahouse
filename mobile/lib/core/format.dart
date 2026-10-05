import 'package:flutter/painting.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../l10n/strings.dart';

/// Turkmen messages for the `timeago` package: "3 minut öň", "2 sagat öň", "dün".
class TkMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  // Each message already contains "öň" so that "şu wagt" and "dün" read naturally.
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';
  @override
  String lessThanOneMinute(int seconds) => S.justNow;
  @override
  String aboutAMinute(int minutes) => S.minutesAgo(1);
  @override
  String minutes(int minutes) => S.minutesAgo(minutes);
  @override
  String aboutAnHour(int minutes) => S.hoursAgo(1);
  @override
  String hours(int hours) => S.hoursAgo(hours);
  @override
  String aDay(int hours) => S.yesterday;
  @override
  String days(int days) => S.daysAgo(days);
  @override
  String aboutAMonth(int days) => S.monthsAgo(1);
  @override
  String months(int months) => S.monthsAgo(months);
  @override
  String aboutAYear(int year) => S.yearsAgo(1);
  @override
  String years(int years) => S.yearsAgo(years);
  @override
  String wordSeparator() => ' ';
}

const _locale = 'tk';
bool _registered = false;

void registerTimeagoLocale() {
  if (_registered) return;
  timeago.setLocaleMessages(_locale, TkMessages());
  _registered = true;
}

/// Relative time in Turkmen, e.g. "5 minut öň".
String timeAgo(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  registerTimeagoLocale();
  return timeago.format(date, locale: _locale, clock: now);
}

/// Compact counts: 950, 1,2 müň, 12 müň, 1,4 mln.
String compactCount(int n) {
  String one(double v) {
    final s = v.toStringAsFixed(1).replaceAll('.', ',');
    return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
  }

  if (n < 1000) return '$n';
  if (n < 1000000) {
    final v = n / 1000;
    return '${v < 10 ? one(v) : v.round()} ${S.thousand}';
  }
  return '${one(n / 1000000)} ${S.million}';
}

const _avatarColors = <Color>[
  Color(0xFFD6336C),
  Color(0xFF7A3E2B),
  Color(0xFFC98A10),
  Color(0xFF1B4965),
  Color(0xFF4B3A73),
  Color(0xFF2D6A4F),
  Color(0xFF9C3D54),
  Color(0xFF5E3B36),
];

/// Stable color for a user's letter avatar (same algorithm as the web client).
Color colorFor(String key) {
  var h = 0;
  for (final c in key.runes) {
    h = (h * 31 + c) & 0xFFFFFFFF;
  }
  return _avatarColors[h % _avatarColors.length];
}

/// Parses `#rrggbb` / `#rgb`; returns [fallback] when the value is invalid.
Color parseHexColor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Splits "a, b,c" into trimmed, non-empty tags.
List<String> splitTags(String raw) =>
    raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
