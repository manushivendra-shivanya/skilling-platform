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
        _HazardTapeDivider(pack: pack),
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

/// Diagonal hazard-tape divider between the lesson list and the process
/// clips section -- traced from the published Shift Floor mock's
/// `.hazard-divider` device (`repeating-linear-gradient(-45deg, hazard 0
/// 8px, navy 8px 16px)`, 7px tall).
///
/// This is deliberately a private, screen-scoped widget rather than a
/// fifth entry in `sector_pack/presentation/` -- per
/// `docs/adr/0020-sector-pack-abstraction.md`, only the four contracted
/// slots (signal / list row / task object / credential) are meant to be
/// shared structural widgets. A divider used in exactly one place is
/// screen-specific content styled with the pack's tokens directly, not a
/// new reusable component.
///
/// Colours: `AppColors.navy` for the dark stripe, not a colour derived
/// from `pack.primaryAccent` -- this is persistent structural chrome
/// (always visible once Lessons has any clips), the same category of
/// "don't darken primaryAccent toward black for this" case that produced
/// the Learn tab bar's muddy-brown bug this session (see
/// `AppColors.navy`'s own doc comment in `app_colors.dart`). The amber
/// stripe reads `pack.signalPalette.active` so the divider still resolves
/// entirely from `pack`, just not from `primaryAccent`.
class _HazardTapeDivider extends StatelessWidget {
  const _HazardTapeDivider({required this.pack});

  final SectorPack pack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7,
      width: double.infinity,
      child: CustomPaint(
        painter: _HazardStripePainter(
          navy: AppColors.navy,
          amber: pack.signalPalette.active,
        ),
      ),
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  const _HazardStripePainter({required this.navy, required this.amber});

  final Color navy;
  final Color amber;

  /// 8px amber + 8px navy, matching the mock's
  /// `repeating-linear-gradient(-45deg, hazard 0 8px, navy 8px 16px)`.
  static const double _stripeWidth = 8;
  static const double _period = _stripeWidth * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(bounds, Paint()..color = navy);
    // -45deg diagonal amber bands: each band is a thick diagonal line from
    // the bottom-left corner of its period to the top-right, stepped
    // across the full width (plus one extra period of overscan on each
    // side so the diagonal still fully covers the top/bottom corners).
    // A stroke's `strokeWidth` is measured perpendicular to the line; at a
    // 45deg line angle the *horizontal* cross-section of that stroke is
    // strokeWidth / sin(45deg) = strokeWidth * sqrt(2). Dividing by
    // sqrt(2) here keeps each drawn band exactly `_stripeWidth` (8px)
    // wide when measured horizontally, matching the CSS repeating
    // gradient's 8px hazard / 8px navy period.
    final stripePaint = Paint()
      ..color = amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stripeWidth / 1.4142135623730951;
    for (
      var x = -size.height - _period;
      x < size.width + size.height + _period;
      x += _period
    ) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HazardStripePainter oldDelegate) =>
      oldDelegate.navy != navy || oldDelegate.amber != amber;
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
