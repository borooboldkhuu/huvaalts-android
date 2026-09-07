import '../errors/failure.dart';

/// A minimal Result type so repositories return either data or a [Failure]
/// instead of throwing across layer boundaries. Deliberately small (not a
/// full fpdart/dartz dependency) to keep the core layer dependency-light.
sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.ok(T data) = ApiOk<T>;
  factory ApiResult.error(Failure failure) = ApiError<T>;

  bool get isOk => this is ApiOk<T>;

  R when<R>({
    required R Function(T data) ok,
    required R Function(Failure failure) error,
  }) {
    final self = this;
    if (self is ApiOk<T>) return ok(self.data);
    if (self is ApiError<T>) return error(self.failure);
    throw StateError('Unreachable ApiResult subtype');
  }
}

class ApiOk<T> extends ApiResult<T> {
  const ApiOk(this.data);
  final T data;
}

class ApiError<T> extends ApiResult<T> {
  const ApiError(this.failure);
  final Failure failure;
}
