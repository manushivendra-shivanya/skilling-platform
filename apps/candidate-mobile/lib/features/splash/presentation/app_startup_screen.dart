import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_state_view.dart';
import 'app_startup_controller.dart';

class AppStartupScreen extends ConsumerStatefulWidget {
  const AppStartupScreen({this.onReady, super.key});

  final VoidCallback? onReady;

  @override
  ConsumerState<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends ConsumerState<AppStartupScreen> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(appStartupControllerProvider, (previous, next) {
      if (!_hasNavigated && next.hasValue && widget.onReady != null) {
        _hasNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onReady!();
          }
        });
      }
    });

    final startupState = ref.watch(appStartupControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: startupState.when(
          loading: () => const _AppStartupLoadingView(),
          error: (error, stackTrace) => _AppStartupErrorView(
            message: error is AppFailure
                ? error.message
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
              Icon(
                AppIcons.coach,
                color: Theme.of(context).colorScheme.primary,
                size: 56,
              ),
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
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
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
