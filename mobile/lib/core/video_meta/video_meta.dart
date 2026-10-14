import 'dart:typed_data';

import 'video_meta_io.dart'
    if (dart.library.js_interop) 'video_meta_web.dart'
    as impl;

/// Length and first-frame poster of a picked video.
class VideoMeta {
  const VideoMeta({this.duration, this.poster, this.width, this.height});

  /// Seconds.
  final double? duration;

  /// JPEG bytes of a frame near the start.
  final Uint8List? poster;
  final int? width;
  final int? height;
}

/// Reads [VideoMeta] for a picked video. On the web the browser decodes the
/// file and draws a frame to a canvas; elsewhere this returns null and the
/// server draws a placeholder poster.
Future<VideoMeta?> readVideoMeta(String? path) =>
    path == null ? Future.value() : impl.readVideoMeta(path);
