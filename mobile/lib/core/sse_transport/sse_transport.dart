import '../api_client.dart';
import '../sse.dart';
import 'sse_transport_io.dart'
    if (dart.library.js_interop) 'sse_transport_web.dart'
    as impl;

/// Opens `GET /api/events` on the current server.
///
/// Android: a dio request with `ResponseType.stream` through the shared
/// client (its interceptors add the token and the current server address).
/// Web: `fetch` with a readable body, because dio's browser adapter only
/// delivers the response when it is complete.
Future<SseStream> openEventStream(ApiClient client, String token) =>
    impl.openEventStream(client, token);
