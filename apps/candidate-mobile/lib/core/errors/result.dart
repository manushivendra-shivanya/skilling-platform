import 'app_failure.dart';

sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  });
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) => success(value);
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.value);

  final AppFailure value;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) => failure(value);
}
