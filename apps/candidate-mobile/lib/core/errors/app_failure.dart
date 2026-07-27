sealed class AppFailure {
  const AppFailure(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause, super.stackTrace});
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
