import 'json.dart';

class Category {
  const Category({required this.slug, required this.name});

  factory Category.fromJson(Json j) =>
      Category(slug: asString(j['slug']), name: asString(j['name']));

  final String slug;
  final String name;
}

/// Display name for a slug, or the slug itself when unknown.
String categoryName(String slug, List<Category>? categories) {
  for (final c in categories ?? const <Category>[]) {
    if (c.slug == slug) return c.name;
  }
  return slug;
}
