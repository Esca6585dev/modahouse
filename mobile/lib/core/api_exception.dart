import 'package:dio/dio.dart';

import '../l10n/strings.dart';

/// Every failed API call ends up as an [ApiException] with a Turkmen message.
class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode = 0]);

  final String message;

  /// HTTP status, or 0 when the server could not be reached.
  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Message for a status code when the body has no `{"error": "..."}`.
String fallbackMessage(int status) {
  switch (status) {
    case 401:
      return S.unauthorized;
    case 403:
      return S.forbidden;
    case 404:
      return S.notFound;
    case 413:
      return S.fileTooLarge;
    case 429:
      return S.tooManyRequests;
    default:
      return status >= 500 ? S.serverError : S.genericError;
  }
}

/// Reads `{"error": "..."}` from a response body (already decoded or raw).
String? errorFromBody(Object? data) {
  if (data is Map) {
    final e = data['error'];
    if (e is String && e.trim().isNotEmpty) return e;
  }
  return null;
}

/// Converts any error thrown by Dio into an [ApiException].
ApiException mapDioError(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    if (error.error is ApiException) return error.error as ApiException;
    final res = error.response;
    if (res != null) {
      final status = res.statusCode ?? 0;
      return ApiException(
        errorFromBody(res.data) ?? fallbackMessage(status),
        status,
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(S.timeout);
      case DioExceptionType.cancel:
        return const ApiException(S.genericError);
      default:
        return const ApiException(S.networkError);
    }
  }
  return const ApiException(S.genericError);
}

/// Human readable message for any error (used by SnackBars and error views).
String errorMessage(Object? error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return mapDioError(error).message;
  return S.genericError;
}
