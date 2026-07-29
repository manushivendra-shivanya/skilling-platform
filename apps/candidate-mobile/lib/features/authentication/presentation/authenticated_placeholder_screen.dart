import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_state_view.dart';
import 'candidate_session_controller.dart';
import 'development_auth_controller.dart';

class AuthenticatedPlaceholderScreen extends ConsumerWidget {
  const AuthenticatedPlaceholderScreen({
    required this.onContinueToOnboarding,
    required this.onLoggedOut,
    super.key,
  });

  final VoidCallback onContinueToOnboarding;
  final VoidCallback onLoggedOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(candidateSessionControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: sessionState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorState(
            title: 'We could not load your session',
            message: 'Close and reopen the app, or try signing in again.',
            actionLabel: null,
          ),
          data: (session) {
            if (session == null || !session.isAuthenticated) {
              return AppStateView(
                icon: AppIcons.info,
                title: 'You are signed out',
                message: 'Return to the welcome screen to sign in.',
                actionLabel: 'Return to welcome',
                onAction: onLoggedOut,
              );
            }
            return _AuthenticatedContent(
              onContinueToOnboarding: onContinueToOnboarding,
              onLogout: () async {
                final failure = await ref
                    .read(candidateSessionControllerProvider.notifier)
                    .logout();
                if (failure == null) {
                  ref.read(developmentAuthControllerProvider.notifier).clear();
                  onLoggedOut();
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _AuthenticatedContent extends StatelessWidget {
  const _AuthenticatedContent({
    required this.onContinueToOnboarding,
    required this.onLogout,
  });

  final VoidCallback onContinueToOnboarding;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.success, size: 72, color: AppColors.success),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Development sign-in complete',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your secure local session is ready. Continue with your candidate profile.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Continue to profile setup',
              onPressed: onContinueToOnboarding,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Log out',
              variant: AppButtonVariant.secondary,
              onPressed: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
