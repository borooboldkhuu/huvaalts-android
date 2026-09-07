import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import '../security/token_manager.dart';
import 'interceptors/auth_interceptor.dart';

/// Thin wrapper around [Dio] for calls to backend endpoints that must not
/// run on-device (DAN auth exchange, payment intent creation, payout
/// triggers — see spec sections 9, 19, 20). Supabase table/storage access
/// itself goes through the `supabase_flutter` client directly, not Dio.
class DioClient {
  DioClient({required String baseUrl, required TokenManager tokenManager})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      ) {
    _dio.interceptors.add(AuthInterceptor(tokenManager));
  }

  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _guard(() => _dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _guard(() => _dio.post<T>(path, data: data));

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _guard(() => _dio.patch<T>(path, data: data));

  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      _guard(() => _dio.delete<T>(path, data: data));

  Future<Response<T>> _guard<T>(
    Future<Response<T>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final int? status = e.response?.statusCode;
        return switch (status) {
          401 => const UnauthorizedException(),
          403 => const ForbiddenException(),
          404 => const NotFoundException(),
          409 => const ConflictException(),
          422 => const ValidationException(message: 'validation_error'),
          429 => const RateLimitedException(),
          _ => const UnknownException(),
        };
      case DioExceptionType.cancel:
        return const UnknownException(message: 'request_cancelled');
      case DioExceptionType.badCertificate:
        return const NetworkException(message: 'bad_certificate');
      case DioExceptionType.unknown:
        return UnknownException(message: e.message ?? 'unknown_error', cause: e);
    }
  }
}
