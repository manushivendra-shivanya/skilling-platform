import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../domain/home_dashboard_repository.dart';
import 'home_dashboard_controller.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({
    required this.onOpenCoach,
    required this.onOpenDiagnostic,
    required this.onOpenVoiceInterview,
    super.key,
  });

  final VoidCallback onOpenCoach;
  final VoidCallback onOpenDiagnostic;
  final VoidCallback onOpenVoiceInterview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeDashboardControllerProvider);
    return dashboard.when(
      loading: () => const _HomeLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: 'Home could not be loaded',
        message: error is AppFailure
            ? error.message
            : 'Your local dashboard is temporarily unavailable.',
        onAction: () =>
            ref.read(homeDashboardControllerProvider.notifier).refresh(),
      ),
      data: (value) {
        if (value == null) {
          return AppEmptyState(
            title: 'Your journey starts here',
            message:
                'Complete profile setup to receive a daily mission and pathway.',
            actionLabel: 'Refresh',
            onAction: () =>
                ref.read(homeDashboardControllerProvider.notifier).refresh(),
          );
        }
        return _HomeContent(
          dashboard: value,
          onOpenCoach: onOpenCoach,
          onOpenDiagnostic: onOpenDiagnostic,
          onOpenVoiceInterview: onOpenVoiceInterview,
          onRefresh: () =>
              ref.read(homeDashboardControllerProvider.notifier).refresh(),
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.dashboard,
    required this.onOpenCoach,
    required this.onOpenDiagnostic,
    required this.onOpenVoiceInterview,
    required this.onRefresh,
  });

  final HomeDashboard dashboard;
  final VoidCallback onOpenCoach;
  final VoidCallback onOpenDiagnostic;
  final VoidCallback onOpenVoiceInterview;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          112,
        ),
        children: [
          Text('Namaste!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          const Text('One practical step at a time.'),
          if (dashboard.pendingSyncCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            AppPendingSyncBanner(pendingCount: dashboard.pendingSyncCount),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your career pathway',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Complete a four-question logistics diagnostic for an explainable role and learning recommendation.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Open career diagnostic',
                  onPressed: onOpenDiagnostic,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            backgroundColor: AppColors.infoSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.record_voice_over_outlined,
                  size: 40,
                  color: AppColors.brand,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Voice interview practice',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Record three logistics answers, review the transcript, and receive transparent development feedback.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Start voice practice',
                  leadingIcon: Icons.mic_none_outlined,
                  onPressed: onOpenVoiceInterview,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            backgroundColor: AppColors.brandSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Today’s mission',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Learn how to report an inventory mismatch clearly.',
                ),
                const SizedBox(height: AppSpacing.md),
                const AppButton(
                  label: 'Mission arrives in Learning',
                  onPressed: null,
                  semanticLabel:
                      'Mission action. Available in the Learning pathway.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppProgress(
                  value: dashboard.readinessProgress,
                  label: 'Practice readiness',
                  detail:
                      '${(dashboard.readinessProgress * 100).round()}% estimate',
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Local mock estimate—not an employer score or hiring decision.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppProgress(
                  value: dashboard.learningProgress,
                  label: 'Learning progress',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(AppIcons.coach, size: 40, color: AppColors.brand),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Ask your Career Coach',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(label: 'Open AI Coach', onPressed: onOpenCoach),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.work_outline),
              title: Text('Job matches'),
              subtitle: Text(
                'Three transparent demo opportunities are available in Jobs.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 180, height: 32),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(height: 140),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 180),
        ],
      ),
    );
  }
}
