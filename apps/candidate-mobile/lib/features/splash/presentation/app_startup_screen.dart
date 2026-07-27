import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_state_view.dart';
import 'app_startup_controller.dart';

class AppStartupScreen extends ConsumerWidget {
  const AppStartupScreen({this.onOpenComponentGallery, super.key});

  final VoidCallback? onOpenComponentGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          data: (state) => _AppStartupReadyView(
            isLowDataMode: state.isLowDataMode,
            onOpenComponentGallery: onOpenComponentGallery,
          ),
        ),
      ),
    );
  }
}

class _AppStartupLoadingView extends StatelessWidget {
  const _AppStartupLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Preparing your skilling journey',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Preparing your skilling journey…'),
          ],
        ),
      ),
    );
  }
}

class _AppStartupReadyView extends StatelessWidget {
  const _AppStartupReadyView({
    required this.isLowDataMode,
    required this.onOpenComponentGallery,
  });

  final bool isLowDataMode;
  final VoidCallback? onOpenComponentGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Semantics(
          label: 'Skilling platform app ready',
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
                'Your skilling journey starts here',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The app foundation is ready for your onboarding experience.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (isLowDataMode) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppStatusChip(
                  label: 'Low-data mode is active',
                  tone: AppChipTone.info,
                ),
              ],
              if (onOpenComponentGallery != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Open component gallery',
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: onOpenComponentGallery,
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
