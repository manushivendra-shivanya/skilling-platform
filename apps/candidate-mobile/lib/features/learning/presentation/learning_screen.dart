import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../../micro_lessons/presentation/warehouse_clips_section.dart';
import '../domain/learning_repository.dart';
import 'learning_controller.dart';

class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(learningControllerProvider);
    return state.when(
      loading: () => const _LearningLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: 'Learning could not be loaded',
        message: error is AppFailure
            ? error.message
            : 'The local pathway is temporarily unavailable.',
        onAction: () => ref.read(learningControllerProvider.notifier).retry(),
      ),
      data: (value) {
        if (value.units.isEmpty) {
          return const AppEmptyState(
            title: 'No lessons yet',
            message: 'Your pathway will appear here when content is assigned.',
          );
        }
        return _LearningContent(state: value);
      },
    );
  }
}

class _LearningContent extends ConsumerWidget {
  const _LearningContent({required this.state});

  final LearningState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        StreamBuilder<ConnectivityStatus>(
          stream: ref.read(connectivityRepositoryProvider).watchStatus(),
          initialData: ref.read(connectivityRepositoryProvider).currentStatus,
          builder: (context, snapshot) {
            if (snapshot.data != ConnectivityStatus.offline) {
              return const SizedBox.shrink();
            }
            return const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: AppOfflineBanner(
                message:
                    'Offline: only lessons marked Downloaded are available.',
              ),
            );
          },
        ),
        Text(
          'Your logistics pathway',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgress(
          value: state.progress,
          label: 'Local lesson progress',
          detail: '${state.completedIds.length} of ${state.units.length}',
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Progress is stored securely, works offline, and syncs when a configured backend is available. Completion alone is not an employer qualification.',
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final unit in state.units) ...[
          _LessonCard(
            unit: unit,
            downloaded: state.downloadedIds.contains(unit.id),
            completed: state.completedIds.contains(unit.id),
            onDownload: () => ref
                .read(learningControllerProvider.notifier)
                .toggleDownload(unit.id),
            onComplete: () => ref
                .read(learningControllerProvider.notifier)
                .toggleComplete(unit.id),
            onOpen: () async {
              await _showLesson(context, unit);
              await ref
                  .read(learningControllerProvider.notifier)
                  .toggleComplete(unit.id);
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.xl),
        const Divider(),
        const SizedBox(height: AppSpacing.xl),
        const WarehouseClipsSection(),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.unit,
    required this.downloaded,
    required this.completed,
    required this.onDownload,
    required this.onComplete,
    required this.onOpen,
  });

  final LearningUnit unit;
  final bool downloaded;
  final bool completed;
  final VoidCallback onDownload;
  final VoidCallback onComplete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unit.isDailyMission)
            const Text(
              'TODAY’S MISSION',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(unit.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('${unit.durationMinutes} min • Content v${unit.version}'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onDownload,
                icon: Icon(
                  downloaded ? Icons.download_done : Icons.download_outlined,
                ),
                label: Text(downloaded ? 'Downloaded' : 'Download'),
              ),
              FilledButton.icon(
                onPressed: completed ? onComplete : onOpen,
                icon: Icon(completed ? Icons.check_circle : Icons.play_arrow),
                label: Text(completed ? 'Mark incomplete' : 'Open lesson'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showLesson(BuildContext context, LearningUnit unit) async {
  await showAppBottomSheet<void>(
    context: context,
    title: unit.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(unit.content),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Checkpoint: Which action preserves an audit trail during an exception?',
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppCard(
          backgroundColor: AppColors.successSoft,
          child: Text(
            'Record the original and observed values before escalating or correcting.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppBottomSheetCloseButton(),
      ],
    ),
  );
}

class _LearningLoadingView extends StatelessWidget {
  const _LearningLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppSkeleton(height: 80),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 140),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 140),
        ],
      ),
    );
  }
}
