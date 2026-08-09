import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../domain/home_dashboard_repository.dart';
import 'home_dashboard_controller.dart';
import 'journey_step_card.dart';
import 'readiness_ring_card.dart';
import 'today_services_carousel.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({
    required this.onOpenCoach,
    required this.onOpenDiagnostic,
    required this.onOpenVoiceInterview,
    required this.onOpenCareerPassport,
    required this.onOpenJobs,
    required this.onOpenPathway,
    super.key,
  });

  final VoidCallback onOpenCoach;
  final VoidCallback onOpenDiagnostic;
  final VoidCallback onOpenVoiceInterview;
  final VoidCallback onOpenCareerPassport;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenPathway;

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
          onOpenCareerPassport: onOpenCareerPassport,
          onOpenJobs: onOpenJobs,
          onOpenPathway: onOpenPathway,
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
    required this.onOpenCareerPassport,
    required this.onOpenJobs,
    required this.onOpenPathway,
    required this.onRefresh,
  });

  final HomeDashboard dashboard;
  final VoidCallback onOpenCoach;
  final VoidCallback onOpenDiagnostic;
  final VoidCallback onOpenVoiceInterview;
  final VoidCallback onOpenCareerPassport;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenPathway;
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
          Text(
            'Today’s services',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TodayServicesCarousel(
            services: [
              TodayService(
                label: 'Proof',
                icon: Icons.verified_outlined,
                background: AppColors.successSoft,
                foreground: AppColors.success,
                onTap: onOpenCareerPassport,
              ),
              TodayService(
                label: 'Verified Jobs',
                icon: Icons.work_outline,
                background: AppColors.infoSoft,
                foreground: AppColors.info,
                onTap: onOpenJobs,
              ),
              TodayService(
                label: 'Book Consultation',
                icon: Icons.event_available_outlined,
                background: AppColors.accentSoft,
                foreground: AppColors.accent,
              ),
              TodayService(
                label: 'Book Mock Interview',
                icon: Icons.groups_outlined,
                background: AppColors.surfaceMuted,
                foreground: AppColors.ink,
              ),
              TodayService(
                label: 'Your Career Pathway',
                icon: Icons.route_outlined,
                background: AppColors.brandSoft,
                foreground: AppColors.brand,
                onTap: onOpenPathway,
              ),
              TodayService(
                label: 'Voice Interview Practice',
                icon: Icons.record_voice_over_outlined,
                background: AppColors.warningSoft,
                foreground: AppColors.warning,
                onTap: onOpenVoiceInterview,
              ),
              TodayService(
                label: 'Interview Lineup',
                icon: Icons.event_note_outlined,
                background: AppColors.tealSoft,
                foreground: AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          JourneyStepCard(currentStep: _journeyStepFor(dashboard)),
          const SizedBox(height: AppSpacing.md),
          ReadinessRingCard(
            readinessProgress: dashboard.readinessProgress,
            learningProgress: dashboard.learningProgress,
            onOpenDiagnostic: onOpenDiagnostic,
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

/// Derives which journey stage reads as "current" from the two real
/// progress signals the dashboard already tracks. Deliberately coarse
/// (4 reachable states, not a precise per-stage tracker) rather than
/// inventing granularity the backend doesn't actually measure.
JourneyStep _journeyStepFor(HomeDashboard dashboard) {
  if (dashboard.learningProgress < 0.34) return JourneyStep.learn;
  if (dashboard.learningProgress < 1.0) return JourneyStep.practise;
  if (dashboard.readinessProgress < 1.0) return JourneyStep.assess;
  return JourneyStep.apply;
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
