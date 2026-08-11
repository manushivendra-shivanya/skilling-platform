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
import '../../sector_pack/application/active_sector_pack_provider.dart';
import '../../sector_pack/domain/sector_pack.dart';
import '../../sector_pack/presentation/sector_index_row.dart';
import '../../sector_pack/presentation/sector_pack_icons.dart';
import '../../sector_pack/presentation/sector_signal_dot.dart';
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
    final pack = ref.watch(activeSectorPackProvider);
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
        for (final entry in state.units.indexed) ...[
          _LessonRow(
            pack: pack,
            indexLabel: 'L-${(entry.$1 + 1).toString().padLeft(2, '0')}',
            unit: entry.$2,
            downloaded: state.downloadedIds.contains(entry.$2.id),
            completed: state.completedIds.contains(entry.$2.id),
            onDownload: () => ref
                .read(learningControllerProvider.notifier)
                .toggleDownload(entry.$2.id),
            onOpen: () async {
              await _showLesson(context, entry.$2);
              await ref
                  .read(learningControllerProvider.notifier)
                  .toggleComplete(entry.$2.id);
            },
            onMarkIncomplete: () => ref
                .read(learningControllerProvider.notifier)
                .toggleComplete(entry.$2.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.xl),
        const WarehouseClipsSection(),
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.pack,
    required this.indexLabel,
    required this.unit,
    required this.downloaded,
    required this.completed,
    required this.onDownload,
    required this.onOpen,
    required this.onMarkIncomplete,
  });

  final SectorPack pack;
  final String indexLabel;
  final LearningUnit unit;
  final bool downloaded;
  final bool completed;
  final VoidCallback onDownload;
  final VoidCallback onOpen;
  final VoidCallback onMarkIncomplete;

  @override
  Widget build(BuildContext context) {
    final base = '${unit.durationMinutes} min · Content v${unit.version}';
    final statusText = completed
        ? '$base · Completed — tap to mark incomplete'
        : downloaded
        ? '$base · Downloaded'
        : '$base · Tap to open';
    return SectorIndexRow(
      pack: pack,
      indexLabel: indexLabel,
      glyph: completed ? SectorGlyph.check : SectorGlyph.play,
      title: unit.title,
      statusText: statusText,
      signalState: completed
          ? SectorSignalState.cleared
          : downloaded
          ? SectorSignalState.active
          : null,
      missionLabel: unit.isDailyMission ? "TODAY'S MISSION" : null,
      onTap: completed ? onMarkIncomplete : onOpen,
      semanticLabel: completed
          ? '${unit.title}. Completed. Tap to mark incomplete.'
          : '${unit.title}. Tap to open lesson.',
      trailing: _DownloadUtilityButton(
        downloaded: downloaded,
        onPressed: onDownload,
      ),
    );
  }
}

class _DownloadUtilityButton extends StatelessWidget {
  const _DownloadUtilityButton({
    required this.downloaded,
    required this.onPressed,
  });

  final bool downloaded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    return Tooltip(
      message: downloaded ? 'Downloaded' : 'Download for offline',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          // The 36x36 box below is the intended *visual* size (matches
          // the mock) -- this SizedBox+Center keeps that unchanged while
          // expanding the actual tap target to Android's 48dp minimum
          // (kMinInteractiveDimension), the same guarantee Flutter's
          // IconButton gives for free but a hand-rolled InkWell doesn't.
          child: SizedBox(
            width: kMinInteractiveDimension,
            height: kMinInteractiveDimension,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: downloaded ? AppColors.success : divider,
                    width: 1.5,
                  ),
                ),
                child: SectorIcon(
                  glyph: downloaded ? SectorGlyph.check : SectorGlyph.download,
                  color: downloaded
                      ? AppColors.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
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
    // Scrollable: the segmented tab bar above this (Lessons / Practise /
    // Certification) takes noticeably more vertical room than the old
    // plain TabBar once its state-readout text grows at a large
    // accessibility text scale, which can leave less height than this
    // view's fixed skeleton sizes need on a short device.
    return const SingleChildScrollView(
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
