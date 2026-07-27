import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_error_boundary.dart';
import 'app_startup_controller.dart';

class AppStartupScreen extends ConsumerWidget {
  const AppStartupScreen({super.key});

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
    return Center(
      child: Semantics(
        label: 'Preparing your skilling journey',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing your skilling journey…'),
          ],
        ),
      ),
    );
  }
}

class _AppStartupReadyView extends StatelessWidget {
  const _AppStartupReadyView({required this.isLowDataMode});

  final bool isLowDataMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          label: 'Skilling platform app ready',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                'Your skilling journey starts here',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The app foundation is ready for your onboarding experience.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (isLowDataMode) ...[
                const SizedBox(height: 20),
                const Chip(
                  avatar: Icon(Icons.data_saver_on_outlined),
                  label: Text('Low-data mode is active'),
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
    return AppErrorBoundaryContent(
      title: 'We could not prepare the app',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
