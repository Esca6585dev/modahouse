// Small, forgiving JSON readers shared by the model classes.

typedef Json = Map<String, dynamic>;

int asInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String asString(Object? v) => v == null ? '' : '$v';

bool asBool(Object? v) => v == true;

DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

Json asJson(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<T> asList<T>(Object? v, T Function(Object? item) item) =>
    v is List ? v.map(item).toList() : <T>[];

double asDouble(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Like [asInt] but keeps `null` (e.g. `stock: null` = not tracked).
int? asIntOrNull(Object? v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
