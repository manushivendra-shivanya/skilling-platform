import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../domain/candidate_intelligence.dart';
import '../domain/diagnostic_engine.dart';
import 'candidate_intelligence_controller.dart';

class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  final Map<String, int> _answers = {};
  var _questionIndex = -1;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final intelligence = ref.watch(candidateIntelligenceControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Career diagnostic')),
      body: intelligence.when(
        loading: () => const AppStateView(
          icon: Icons.hourglass_top,
          title: 'Loading diagnostic',
          message: 'Restoring your saved pathway.',
        ),
        error: (error, stackTrace) => AppErrorState(
          title: 'Diagnostic could not be loaded',
          message: 'Your saved pathway is temporarily unavailable.',
          onAction: () => ref
              .read(candidateIntelligenceControllerProvider.notifier)
              .retry(),
        ),
        data: (state) {
          if (_questionIndex < 0) {
            return _buildIntroduction(state.diagnosticResult);
          }
          if (_questionIndex < LogisticsIntelligenceCatalog.questions.length) {
            return _buildQuestion();
          }
          return _buildResult(state);
        },
      ),
    );
  }

  Widget _buildIntroduction(DiagnosticResult? previous) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const AppOfflineBanner(
          message:
              'Offline-ready: answers save securely on this device and sync when configured.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          previous == null
              ? 'Find your logistics pathway'
              : 'Review or retake your pathway',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Four practical questions check workflow knowledge. Results explain observed answers and suggest improvement; they never infer personality or automatically reject you.',
        ),
        if (previous != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _ResultSummary(result: previous),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: previous == null ? 'Start diagnostic' : 'Retake diagnostic',
          semanticLabel: 'Start four-question logistics career diagnostic',
          onPressed: () => setState(() {
            _answers.clear();
            _questionIndex = 0;
          }),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final question = LogisticsIntelligenceCatalog.questions[_questionIndex];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        AppProgress(
          value:
              (_questionIndex + 1) /
              LogisticsIntelligenceCatalog.questions.length,
          label:
              'Question ${_questionIndex + 1} of ${LogisticsIntelligenceCatalog.questions.length}',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(question.prompt, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < question.options.length; index++) ...[
          AppCard(
            onTap: () => setState(() => _answers[question.id] = index),
            semanticLabel:
                '${question.options[index].label}. ${_answers[question.id] == index ? 'Selected' : 'Not selected'}',
            backgroundColor: _answers[question.id] == index
                ? AppColors.brandSoft
                : AppColors.surface,
            child: Row(
              children: [
                Expanded(child: Text(question.options[index].label)),
                Icon(
                  _answers[question.id] == index
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: _answers[question.id] == index
                      ? AppColors.brand
                      : AppColors.outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label:
              _questionIndex ==
                  LogisticsIntelligenceCatalog.questions.length - 1
              ? 'See my pathway'
              : 'Next question',
          onPressed: _answers.containsKey(question.id)
              ? () => setState(() => _questionIndex += 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildResult(CandidateIntelligenceState state) {
    final result = DiagnosticEngine.score(selectedOptionIndexes: _answers);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'Your explainable pathway',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _ResultSummary(result: result),
        const SizedBox(height: AppSpacing.lg),
        for (final competency in result.competencies) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LogisticsIntelligenceCatalog.competencyName(
                    competency.competencyCode,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Observed level: ${competency.level} of 3'),
                Text(competency.explanation),
                const SizedBox(height: AppSpacing.xs),
                Text('Next step: ${competency.improvement}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const Text(
          'This recommendation is guidance, not an employer decision. You can retake it and review all contributing answers.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save pathway',
          isLoading: _saving,
          onPressed: _saving ? null : () => _save(result),
        ),
      ],
    );
  }

  Future<void> _save(DiagnosticResult result) async {
    setState(() => _saving = true);
    final failure = await ref
        .read(candidateIntelligenceControllerProvider.notifier)
        .saveDiagnostic(result);
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure == null) {
      unawaited(
        ref
            .read(analyticsTrackerProvider)
            .track(
              AnalyticsEvent.diagnosticCompleted(result.definitionVersion),
            ),
      );
      showAppSnackBar(
        context: context,
        message: 'Pathway saved. Learning recommendations are now available.',
        tone: AppMessageTone.success,
      );
      setState(() => _questionIndex = -1);
    } else {
      showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      );
    }
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.result});

  final DiagnosticResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.brandSoft,
      semanticLabel:
          'Recommended pathway ${LogisticsIntelligenceCatalog.roleName(result.recommendedRoleCode)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECOMMENDED PATHWAY'),
          Text(
            LogisticsIntelligenceCatalog.roleName(result.recommendedRoleCode),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('Average observed level: ${result.averageLevel} of 3'),
        ],
      ),
    );
  }
}
