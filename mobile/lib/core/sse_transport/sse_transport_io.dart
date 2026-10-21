import 'package:dio/dio.dart';

import '../api_client.dart';
import '../sse.dart';

Future<SseStream> openEventStream(ApiClient client, String token) async {
  final cancel = CancelToken();
  final res = await client.dio.get<ResponseBody>(
    '/events',
    cancelToken: cancel,
    options: Options(
      responseType: ResponseType.stream,
      headers: {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
      // Between chunks: the server pings every 25 s.
      receiveTimeout: const Duration(seconds: 75),
    ),
  );
  final body = res.data;
  if (body == null) throw StateError('empty event stream');
  return SseStream(body.stream, () {
    if (!cancel.isCancelled) cancel.cancel();
  });
}
