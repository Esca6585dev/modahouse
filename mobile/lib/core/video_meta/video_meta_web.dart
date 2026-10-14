import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'video_meta.dart';

Future<VideoMeta?> readVideoMeta(String path) async {
  try {
    final video = web.document.createElement('video') as web.HTMLVideoElement
      ..muted = true
      ..preload = 'auto'
      ..crossOrigin = 'anonymous'
      ..src = path;
    await video.onLoadedData.first.timeout(const Duration(seconds: 8));
    final duration = video.duration.isFinite ? video.duration : null;
    final seekTo = duration == null ? 0.1 : (duration * 0.1).clamp(0.0, 1.0);
    final seeked = video.onSeeked.first.timeout(const Duration(seconds: 5));
    video.currentTime = seekTo;
    await seeked;
    final w = video.videoWidth, h = video.videoHeight;
    if (w == 0 || h == 0) return VideoMeta(duration: duration);
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0);
    final done = Completer<Uint8List?>();
    canvas.toBlob(
      ((web.Blob? blob) {
        if (blob == null) {
          done.complete(null);
          return;
        }
        blob.arrayBuffer().toDart.then(
          (buf) => done.complete(buf.toDart.asUint8List()),
          onError: (_) => done.complete(null),
        );
      }).toJS,
      'image/jpeg',
      0.85.toJS,
    );
    final poster = await done.future.timeout(const Duration(seconds: 5));
    video.src = '';
    return VideoMeta(duration: duration, poster: poster, width: w, height: h);
  } catch (_) {
    return null;
  }
}
