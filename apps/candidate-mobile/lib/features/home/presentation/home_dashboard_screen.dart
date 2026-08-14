import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/home_dashboard_repository.dart';
import 'home_dashboard_controller.dart';
import 'home_header.dart';
import 'journey_timeline_card.dart';
import 'today_mission_card.dart';
import 'upcoming_interview_card.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({
    required this.onOpenDiagnostic,
    required this.onOpenVoiceInterview,
    required this.onOpenPathway,
    required this.onOpenNotifications,
    super.key,
  });

  final VoidCallback onOpenDiagnostic;
  final VoidCallback onOpenVoiceInterview;
  final VoidCallback onOpenPathway;

  /// Home's only route to notifications now that it has no shell AppBar --
  /// see `MainNavigationShell`'s doc comment. Surfaced from `HomeHeader`.
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dashboard = ref.watch(homeDashboardControllerProvider);
    void openNotifications() {
      unawaited(
        ref
            .read(analyticsTrackerProvider)
            .track(AnalyticsEvent.globalActionOpened('notifications')),
      );
      onOpenNotifications();
    }

    return dashboard.when(
      loading: () => const _HomeLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: l10n.homeLoadErrorTitle,
        message: error is AppFailure
            ? error.localizedMessage(l10n)
            : l10n.homeLoadErrorMessage,
        onAction: () =>
            ref.read(homeDashboardControllerProvider.notifier).refresh(),
      ),
      data: (value) {
        if (value == null) {
          return AppEmptyState(
            title: l10n.homeEmptyTitle,
            message: l10n.homeEmptyMessage,
            actionLabel: l10n.actionRefresh,
            onAction: () =>
                ref.read(homeDashboardControllerProvider.notifier).refresh(),
          );
        }
        return _HomeContent(
          dashboard: value,
          onOpenDiagnostic: onOpenDiagnostic,
          onOpenVoiceInterview: onOpenVoiceInterview,
          onOpenPathway: onOpenPathway,
          onOpenNotifications: openNotifications,
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
    required this.onOpenDiagnostic,
    required this.onOpenVoiceInterview,
    required this.onOpenPathway,
    required this.onOpenNotifications,
    required this.onRefresh,
  });

  final HomeDashboard dashboard;
  final VoidCallback onOpenDiagnostic;
  final VoidCallback onOpenVoiceInterview;
  final VoidCallback onOpenPathway;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onRefresh;

  /// How far the mission card rises into the gradient. The header reserves
  /// [_cardLift] + breathing room below its content, and the card is lifted
  /// back up by [_cardLift], so it lands half on the brand block and half on
  /// the page — the overlap the first Home mock had.
  static const double _cardLift = 28;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mission = dashboard.todayMission;
    final interview = dashboard.nextInterview;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          HomeHeader(
            dashboard: dashboard,
            onOpenNotifications: onOpenNotifications,
            bottomInset: mission == null ? 0 : _cardLift + AppSpacing.md,
          ),
          if (mission != null)
            // Transform, not a negative margin: the card keeps its own slot in
            // the list, so the space it vacates below becomes the gap to the
            // next section and nothing overlaps that it shouldn't.
            Transform.translate(
              offset: const Offset(0, -_cardLift),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TodayMissionCard(
                  mission: mission,
                  onStart: onOpenPathway,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              mission == null ? AppSpacing.md : 0,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dashboard.pendingSyncCount > 0) ...[
                  AppPendingSyncBanner(
                    pendingCount: dashboard.pendingSyncCount,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Nothing to do today: the pathway is finished or not yet
                // assigned. Say so and offer the diagnostic, rather than
                // showing a disabled button.
                if (mission == null) ...[
                  AppCard(
                    backgroundColor: AppColors.brandSoft,
                    onTap: onOpenDiagnostic,
                    semanticLabel: l10n.homeNoMissionSemantic,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.homeNoMissionTitle,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(l10n.homeNoMissionBody),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                if (interview != null) ...[
                  UpcomingInterviewCard(
                    interview: interview,
                    onPrepare: onOpenVoiceInterview,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                Text(
                  l10n.homeJourneySectionTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),

                JourneyTimelineCard(dashboard: dashboard, onTap: onOpenPathway),
                const SizedBox(height: AppSpacing.sm),

                // Only one row, and it never duplicates a bottom-nav tab or
                // a CTA already on screen above it. Jobs, Coach, the Career
                // Passport and the diagnostic all live one tap away in the
                // shell; repeating them here made Home a menu instead of a
                // next step. Interview practice is the same story: when
                // UpcomingInterviewCard is already showing its own "Prepare"
                // button above, this row would just be a second way to say
                // the same thing, so it only appears when that card doesn't.
                if (interview == null)
                  _ShortcutRow(
                    icon: Icons.mic_none_outlined,
                    iconBackground: AppColors.infoSoft,
                    iconColor: AppColors.info,
                    title: l10n.homeInterviewPracticeTitle,
                    subtitle: l10n.homeInterviewPracticeSubtitle,
                    onTap: onOpenVoiceInterview,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single tappable destination. Every row on Home is one of these, so no
/// secondary action can be mistaken for the primary one.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          AppIconPlate(
            icon: icon,
            background: iconBackground,
            foreground: iconColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.brand,
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
