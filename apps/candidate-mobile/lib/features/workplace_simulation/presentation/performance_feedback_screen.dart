import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';

class PerformanceFeedbackScreen extends ConsumerStatefulWidget {
  const PerformanceFeedbackScreen({
    required this.missionId,
    required this.onReturnToPractice,
    super.key,
  });

  final String missionId;
  final VoidCallback onReturnToPractice;

  @override
  ConsumerState<PerformanceFeedbackScreen> createState() =>
      _PerformanceFeedbackScreenState();
}

class _PerformanceFeedbackScreenState
    extends ConsumerState<PerformanceFeedbackScreen> {
  bool _tracked = false;

  @override
  Widget build(BuildContext context) {
    final simulation = ref.watch(
      workplaceSimulationControllerProvider(widget.missionId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Feedback')),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Results unavailable',
            message: 'Return to Practice and reopen the mission.',
            actionLabel: 'Back to Practice',
            onAction: widget.onReturnToPractice,
          ),
          data: (value) {
            final result = value.result;
            if (value.mission.id != widget.missionId || result == null) {
              return AppErrorState(
                title: 'No results yet',
                message: 'Complete the shift report before viewing feedback.',
                actionLabel: 'Back to Practice',
                onAction: widget.onReturnToPractice,
              );
            }
            if (!_tracked) {
              _tracked = true;
              unawaited(
                ref
                    .read(
                      workplaceSimulationControllerProvider(
                        widget.missionId,
                      ).notifier,
                    )
                    .recordWorkplaceEvent(
                      AttemptAuditEventType.performanceFeedbackOpened,
                      screenId: 'performance-feedback',
                    ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.mission.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _statusLabel(result.status),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _statusColor(result.status),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overall score',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${result.overallScore.round()}%',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Score categories',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final entry in result.categoryScores.entries) ...[
                        AppCard(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_categoryLabel(entry.key)),
                              Text('${entry.value.round()}%'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Competency evidence',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final score in result.competencyScores) ...[
                        AppCard(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _competencyName(
                                  value.competencies,
                                  score.competencyId,
                                ),
                              ),
                              Text('${score.score}%'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (result.criticalErrors.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Critical errors',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final error in result.criticalErrors) ...[
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  error.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(error.feedback),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                      if (result.missedIssues.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Missed',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final issue in result.missedIssues)
                          Text('✗ $issue'),
                      ],
                      if (result.correctActions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'What went well',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final action in result.correctActions)
                          Text('✓ $action'),
                      ],
                      if (result.recommendedRemediationIds.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Recommended next steps',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final id in result.recommendedRemediationIds)
                          Text('• ${_remediationTitle(value.remediation, id)}'),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Back to Practice',
                        onPressed: widget.onReturnToPractice,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _statusLabel(MissionStatus status) => switch (status) {
  MissionStatus.passed => 'Shift Passed',
  MissionStatus.retryRecommended => 'Retry Recommended',
  MissionStatus.criticalFailure => 'Critical Failure',
  MissionStatus.incomplete => 'Incomplete',
};

Color _statusColor(MissionStatus status) => switch (status) {
  MissionStatus.passed => Colors.green,
  MissionStatus.retryRecommended => Colors.orange,
  MissionStatus.criticalFailure => Colors.red,
  MissionStatus.incomplete => Colors.grey,
};

String _categoryLabel(String categoryId) => categoryId
    .split('-')
    .map((word) => word[0].toUpperCase() + word.substring(1))
    .join(' ');

String _competencyName(List<CompetencyDefinition> competencies, String id) {
  for (final competency in competencies) {
    if (competency.id == id) return competency.name;
  }
  return id;
}

String _remediationTitle(
  List<RemediationRecommendation> remediation,
  String id,
) {
  for (final item in remediation) {
    if (item.id == id) return item.title;
  }
  return id;
}
