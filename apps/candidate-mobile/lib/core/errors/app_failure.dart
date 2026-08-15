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

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.cause, super.stackTrace});
}

final class AuthenticationFailure extends AppFailure {
  const AuthenticationFailure(super.message, {super.cause, super.stackTrace});
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {super.cause, super.stackTrace});
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure(super.message, {super.cause, super.stackTrace});
}

/// The request reached a server that is up but declined to serve it right
/// now -- a 5xx, or a client-side stub standing in for a backend this
/// build has no configuration for.
///
/// Deliberately distinct from [UnexpectedFailure]: "try again in a few
/// minutes" is actionable and true, whereas "something unexpected went
/// wrong" tells a candidate nothing and reads as an app bug. Every AI
/// feature's server-side provider failure arrives this way -- see
/// `ResumeService.parseResume`, which turns *any* provider throw
/// (including an unconfigured `GEMINI_API_KEY`) into a 503.
final class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
