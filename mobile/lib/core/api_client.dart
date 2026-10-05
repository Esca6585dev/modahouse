import 'package:dio/dio.dart';

import '../config.dart';
import 'api_exception.dart';

/// Adds `Authorization: Bearer <token>` and reports 401s on authenticated calls.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.token, this.onUnauthorized});

  final String? Function() token;
  final void Function()? onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final t = token();
    if (t != null && t.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $t';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final hadToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && hadToken) {
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}

/// Thin wrapper around Dio. Every method returns the decoded JSON body and
/// throws [ApiException] on failure.
class ApiClient {
  ApiClient({
    String? baseUrl,
    String? Function()? token,
    void Function()? onUnauthorized,
    Dio? dio,
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? AppConfig.apiBase,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               headers: {'Accept': 'application/json'},
             ),
           ) {
    this.dio.interceptors.add(
      AuthInterceptor(
        token: token ?? () => null,
        onUnauthorized: onUnauthorized,
      ),
    );
  }

  final Dio dio;

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _run(() => dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(
    String path, {
    Object? data,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) => _run(
    () => dio.post<dynamic>(
      path,
      data: data,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    ),
  );

  Future<dynamic> put(String path, {Object? data}) =>
      _run(() => dio.put<dynamic>(path, data: data));

  Future<dynamic> delete(String path) => _run(() => dio.delete<dynamic>(path));

  Future<dynamic> _run(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is String && data.isEmpty) return null;
      return data;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  static Map<String, Object?>? _clean(Map<String, Object?>? q) {
    if (q == null) return null;
    final out = <String, Object?>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out;
  }
}
