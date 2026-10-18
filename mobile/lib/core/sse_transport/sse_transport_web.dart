import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../config.dart';
import '../api_client.dart';
import '../sse.dart';

Future<SseStream> openEventStream(ApiClient client, String token) async {
  final abort = web.AbortController();
  final headers = web.Headers()
    ..append('Accept', 'text/event-stream')
    ..append('Authorization', 'Bearer $token');
  final res = await web.window
      .fetch(
        '${AppConfig.apiBase}/events'.toJS,
        web.RequestInit(
          method: 'GET',
          headers: headers,
          cache: 'no-store',
          signal: abort.signal,
        ),
      )
      .toDart;
  final body = res.body;
  if (!res.ok || body == null) {
    abort.abort();
    throw StateError('event stream: HTTP ${res.status}');
  }
  final reader = body.getReader() as web.ReadableStreamDefaultReader;
  var closed = false;
  final out = StreamController<List<int>>();
  Future<void> pump() async {
    try {
      while (!closed) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        final value = chunk.value;
        if (value != null && value.isA<JSUint8Array>()) {
          out.add((value as JSUint8Array).toDart);
        }
      }
    } catch (e) {
      if (!closed) out.addError(e);
    } finally {
      if (!out.isClosed) unawaited(out.close());
    }
  }

  unawaited(pump());
  return SseStream(out.stream, () {
    if (closed) return;
    closed = true;
    abort.abort();
  });
}
