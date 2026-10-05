import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/models.dart';

/// An image chosen with image_picker, kept as bytes so it works on web too.
class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;

  MultipartFile toMultipart() => MultipartFile.fromBytes(bytes, filename: name);
}

String encodeSegment(String s) => Uri.encodeComponent(s);

Json parseJson(Object? data) => asJson(data);

List<T> parseList<T>(Object? data, T Function(Json) f) =>
    data is List ? data.map((e) => f(asJson(e))).toList() : <T>[];
