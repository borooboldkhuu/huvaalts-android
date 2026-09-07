/// Base class for all exceptions thrown from the data layer (repositories,
/// data sources). Never let a raw [Exception]/[Error] escape a repository —
/// wrap it in one of these so the UI layer can render a clean message
/// (see spec section 39: never expose raw exceptions to users).
sealed class AppException implements Exception {
  const AppException({required this.message, this.cause});

  /// Human-readable, localization-key-safe message. UI code should map this
  /// to a localized string rather than displaying it verbatim when possible.
  final String message;

  /// The original error, kept for logging/Crashlytics only — never shown
  /// to the user.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  const NetworkException({super.message = 'network_error', super.cause});
}

/// Named to avoid colliding with `dart:async`'s [Exception] of the same
/// short name if a call site imports both.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException({super.message = 'timeout_error', super.cause});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({super.message = 'unauthorized', super.cause});
}

class ForbiddenException extends AppException {
  const ForbiddenException({super.message = 'forbidden', super.cause});
}

class NotFoundException extends AppException {
  const NotFoundException({super.message = 'not_found', super.cause});
}

class ValidationException extends AppException {
  const ValidationException({required super.message, this.fieldErrors, super.cause});

  final Map<String, String>? fieldErrors;
}

class ConflictException extends AppException {
  const ConflictException({super.message = 'conflict', super.cause});
}

/// Server rejected the request due to rate limiting / abuse detection.
class RateLimitedException extends AppException {
  const RateLimitedException({super.message = 'rate_limited', super.cause});
}

class SessionExpiredException extends AppException {
  const SessionExpiredException({super.message = 'session_expired', super.cause});
}

class UnknownException extends AppException {
  const UnknownException({super.message = 'unknown_error', super.cause});
}
