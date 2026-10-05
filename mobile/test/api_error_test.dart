import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/core/api_client.dart';
import 'package:modahouse/core/api_exception.dart';
import 'package:modahouse/l10n/strings.dart';

/// Answers every request with a fixed status and body, recording requests.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, [this.body]);

  final int status;
  final Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final text = body == null
        ? ''
        : (body is String ? body as String : jsonEncode(body));
    return ResponseBody.fromString(
      text,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Simulates "server unreachable".
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  );

  @override
  void close({bool force = false}) {}
}

ApiClient _client(
  HttpClientAdapter adapter, {
  String? token,
  void Function()? onUnauthorized,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    token: () => token,
    onUnauthorized: onUnauthorized,
  );
}

DioException _bad(int status, Object? data) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  group('mapDioError', () {
    test('uses the Turkmen {"error"} message and status', () {
      final e = mapDioError(_bad(400, {'error': 'Ady hökmany'}));
      expect(e.message, 'Ady hökmany');
      expect(e.statusCode, 400);
    });

    test('falls back to a status message when the body has no error', () {
      expect(mapDioError(_bad(404, null)).message, S.notFound);
      expect(mapDioError(_bad(403, 'html')).message, S.forbidden);
      expect(mapDioError(_bad(401, {})).message, S.unauthorized);
      expect(mapDioError(_bad(413, null)).message, S.fileTooLarge);
      expect(mapDioError(_bad(429, null)).message, S.tooManyRequests);
      expect(mapDioError(_bad(502, null)).message, S.serverError);
      expect(mapDioError(_bad(418, null)).message, S.genericError);
    });

    test('network errors and timeouts', () {
      final req = RequestOptions(path: '/x');
      final offline = mapDioError(
        DioException.connectionError(requestOptions: req, reason: 'x'),
      );
      expect(offline.message, S.networkError);
      expect(offline.statusCode, 0);
      final slow = mapDioError(
        DioException.receiveTimeout(
          timeout: Duration.zero,
          requestOptions: req,
        ),
      );
      expect(slow.message, S.timeout);
    });

    test('non-Dio errors become a generic ApiException', () {
      expect(mapDioError(StateError('x')).message, S.genericError);
      const keep = ApiException('Bar', 409);
      expect(identical(mapDioError(keep), keep), isTrue);
      expect(errorMessage(keep), 'Bar');
      expect(errorMessage(Exception('x')), S.genericError);
    });
  });

  group('ApiClient', () {
    test('adds the bearer token and returns decoded JSON', () async {
      final adapter = _FakeAdapter(200, {'status': 'ok'});
      final api = _client(adapter, token: 'abc');
      final data = await api.get(
        '/health',
        query: {'q': '', 'page': 1, 'x': null},
      );
      expect(data, {'status': 'ok'});
      expect(adapter.requests.single.headers['Authorization'], 'Bearer abc');
      // Empty and null query values are dropped.
      expect(adapter.requests.single.queryParameters, {'page': 1});
    });

    test('no Authorization header without a token', () async {
      final adapter = _FakeAdapter(204);
      final api = _client(adapter);
      expect(await api.post('/notifications/read-all'), isNull);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test(
      'failed responses throw ApiException with the server message',
      () async {
        final api = _client(
          _FakeAdapter(409, {'error': 'Bu ulanyjy ady eýýäm bar'}),
        );
        await expectLater(
          api.post('/auth/register', data: {}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Bu ulanyjy ady eýýäm bar')
                .having((e) => e.statusCode, 'status', 409),
          ),
        );
      },
    );

    test('401 on an authenticated request triggers onUnauthorized', () async {
      var calls = 0;
      final api = _client(
        _FakeAdapter(401, {'error': 'Ilki ulgama giriň'}),
        token: 'old',
        onUnauthorized: () => calls++,
      );
      await expectLater(
        api.get('/me'),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, '401', isTrue),
        ),
      );
      expect(calls, 1);
    });

    test('401 without a token (wrong password) does not log out', () async {
      var calls = 0;
      final api = _client(
        _FakeAdapter(401, {'error': 'Parol nädogry'}),
        onUnauthorized: () => calls++,
      );
      await expectLater(
        api.post('/auth/login', data: {}),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
    });

    test('offline server maps to the network message', () async {
      final api = _client(_OfflineAdapter());
      await expectLater(
        api.get('/pins'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            S.networkError,
          ),
        ),
      );
    });
  });
}
