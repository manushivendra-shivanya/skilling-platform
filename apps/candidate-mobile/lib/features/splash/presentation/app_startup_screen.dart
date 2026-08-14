import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/coach_mark.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/app_startup_state.dart';
import 'app_startup_controller.dart';

class AppStartupScreen extends ConsumerStatefulWidget {
  const AppStartupScreen({this.onReady, super.key});

  final FutureOr<void> Function(AppStartupState state)? onReady;

  @override
  ConsumerState<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends ConsumerState<AppStartupScreen> {
  bool _hasNavigated = false;

  // `ref.listen`'s callback only fires on a *change* -- previous vs. next --
  // never for the value the provider already held the instant this widget's
  // listener was registered. appStartupControllerProvider is a plain
  // (non-autoDispose) AsyncNotifierProvider, so its resolved `data` state
  // survives independently of this screen's own lifecycle: if an
  // AppStartupScreen is ever mounted a *second* time while that state is
  // already sitting resolved in the container (this used to happen every
  // time appRouterProvider rebuilt after Google sign-in and threw away the
  // old GoRouter -- see the comment on appRouterProvider), `ref.watch` below
  // returns `data` on the very first build, `ref.listen` never sees a
  // transition into it, and `onReady` is never called. The screen then sits
  // on its *ready* view forever -- no spinner, because it genuinely isn't
  // loading -- with literally nothing left to wait on. That is exactly the
  // real-device report: a static "Saksham" splash, no progress indicator,
  // that never moves.
  //
  // Fixing appRouterProvider's identity already stops it from happening in
  // practice, but this screen has no business depending on that elsewhere
  // never changing again. Checking the *current* value on every build,
  // rather than only reacting to `ref.listen`'s transitions, means an
  // already-resolved state is handled exactly like one that resolves after
  // mount -- there is no "arrived already done" gap left to fall into.
  void _handleStartupState(AsyncValue<AppStartupState> value) {
    final readyState = value.valueOrNull;
    if (_hasNavigated || readyState == null || widget.onReady == null) {
      return;
    }
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onReady!(readyState);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appStartupControllerProvider, (previous, next) {
      _handleStartupState(next);
    });

    final startupState = ref.watch(appStartupControllerProvider);
    _handleStartupState(startupState);

    return Scaffold(
      body: SafeArea(
        child: startupState.when(
          loading: () => const _AppStartupLoadingView(),
          error: (error, stackTrace) => _AppStartupErrorView(
            message: error is AppFailure
                ? error.localizedMessage(AppLocalizations.of(context))
                : 'Please check your connection and try again.',
            onRetry: () =>
                ref.read(appStartupControllerProvider.notifier).retry(),
          ),
          data: (state) =>
              _AppStartupReadyView(isLowDataMode: state.isLowDataMode),
        ),
      ),
    );
  }
}

class _AppStartupLoadingView extends StatelessWidget {
  const _AppStartupLoadingView();

  @override
  Widget build(BuildContext context) {
    return const _SplashBrand(isLoading: true);
  }
}

class _AppStartupReadyView extends StatelessWidget {
  const _AppStartupReadyView({required this.isLowDataMode});

  final bool isLowDataMode;

  @override
  Widget build(BuildContext context) {
    return _SplashBrand(isLowDataMode: isLowDataMode);
  }
}

class _SplashBrand extends StatelessWidget {
  const _SplashBrand({this.isLoading = false, this.isLowDataMode = false});

  final bool isLoading;
  final bool isLowDataMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Semantics(
          label: isLoading
              ? 'Saksham, preparing your skilling journey'
              : 'Saksham is ready',
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoachMark(color: Theme.of(context).colorScheme.primary, size: 56),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Saksham',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Skills se rozgaar tak',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (isLoading) ...[
                const SizedBox(height: AppSpacing.xl),
                const AppLoadingProgressBar(label: 'Getting things ready…'),
              ],
              if (isLowDataMode) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppStatusChip(
                  label: 'Low-data mode is active',
                  tone: AppChipTone.info,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppStartupErrorView extends StatelessWidget {
  const _AppStartupErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: 'We could not prepare the app',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
