import 'app_exception.dart';

/// Maps an [AppException] (or any thrown error) to a [Failure] the
/// presentation layer can pattern-match on to render the right empty/error
/// state (spec section 39/43). Controllers should catch exceptions at the
/// repository boundary and store a [Failure] in state — never a raw
/// exception or stack trace.
sealed class Failure {
  const Failure(this.message);

  final String message;

  factory Failure.from(Object error) {
    if (error is AppException) {
      return switch (error) {
        NetworkException() => NetworkFailure(error.message),
        RequestTimeoutException() => NetworkFailure(error.message),
        UnauthorizedException() => AuthFailure(error.message),
        SessionExpiredException() => AuthFailure(error.message),
        ForbiddenException() => PermissionFailure(error.message),
        NotFoundException() => NotFoundFailure(error.message),
        ValidationException() => ValidationFailure(error.message, error.fieldErrors),
        ConflictException() => ConflictFailure(error.message),
        RateLimitedException() => RateLimitFailure(error.message),
        UnknownException() => UnexpectedFailure(error.message),
      };
    }
    return UnexpectedFailure(error.toString());
  }
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, this.fieldErrors);

  final Map<String, String>? fieldErrors;
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
