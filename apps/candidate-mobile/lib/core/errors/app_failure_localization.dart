import '../../l10n/generated/app_localizations.dart';
import 'app_failure.dart';

/// [AppFailure.message] is English-only, internal text -- meant for logs
/// and developer-facing debugging (see the ~190 call sites across every
/// repository/controller in the app that construct one, none of which have
/// a `BuildContext` to localize with even if they wanted to). Showing it to
/// a candidate directly, as every screen's error state used to, meant the
/// one part of an error screen that actually said what went wrong stayed
/// English regardless of the app's language setting.
///
/// This maps by failure *type* instead -- eight wide categories, each with
/// one honest, localized, generic sentence -- rather than attempting to
/// translate all ~190 individual internal messages themselves. A screen
/// that wants to say something more specific than its failure type still
/// can, by writing its own copy instead of calling this.
extension AppFailureLocalization on AppFailure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.failureNetwork,
    StorageFailure() => l10n.failureStorage,
    ValidationFailure() => l10n.failureValidation,
    AuthenticationFailure() => l10n.failureAuthentication,
    PermissionFailure() => l10n.failurePermission,
    TimeoutFailure() => l10n.failureTimeout,
    ServiceUnavailableFailure() => l10n.failureServiceUnavailable,
    UnexpectedFailure() => l10n.failureUnexpected,
  };
}
