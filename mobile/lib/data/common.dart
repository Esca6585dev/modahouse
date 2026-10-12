import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/models.dart';

/// A photo or video chosen with image_picker, kept as bytes so it works on
/// the web too.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.name,
    this.mimeType,
    this.duration,
    this.poster,
    this.path,
  });

  final Uint8List bytes;
  final String name;

  /// From the picker when known (web gives it reliably).
  final String? mimeType;

  /// Video length in seconds, when it could be read.
  final double? duration;

  /// Video poster (first frame), when one could be made.
  final PickedImage? poster;

  /// Picker path (a blob: URL on the web), used to preview videos.
  final String? path;

  bool get isVideo => mediaTypeFor(name, mimeType).startsWith('video/');

  PickedImage copyWith({double? duration, PickedImage? poster}) => PickedImage(
    bytes: bytes,
    name: name,
    mimeType: mimeType,
    duration: duration ?? this.duration,
    poster: poster ?? this.poster,
    path: path,
  );

  MultipartFile toMultipart() => MultipartFile.fromBytes(
    bytes,
    filename: name,
    contentType: DioMediaType.parse(mediaTypeFor(name, mimeType)),
  );
}

/// MIME type from the picker, or guessed from the file extension.
String mediaTypeFor(String name, [String? mime]) {
  if (mime != null && mime.contains('/')) return mime;
  final ext = name.toLowerCase().split('.').last;
  switch (ext) {
    case 'mp4':
    case 'm4v':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

String encodeSegment(String s) => Uri.encodeComponent(s);

Json parseJson(Object? data) => asJson(data);

List<T> parseList<T>(Object? data, T Function(Json) f) =>
    data is List ? data.map((e) => f(asJson(e))).toList() : <T>[];
