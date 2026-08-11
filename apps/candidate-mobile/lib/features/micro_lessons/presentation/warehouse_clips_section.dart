import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../sector_pack/application/active_sector_pack_provider.dart';
import '../../sector_pack/domain/sector_pack.dart';
import '../../sector_pack/presentation/sector_pack_icons.dart';
import '../../sector_pack/presentation/sector_pack_typography.dart';
import '../domain/micro_lesson_clip.dart';
import 'micro_lesson_clip_controller.dart';
import 'micro_lesson_player_screen.dart';
import 'not_employer_evidence_banner.dart';

/// "Warehouse process clips" section: 10-second process clips grouped by
/// domain, embedded in the real Learning tab (v0.1 -- content browsing and
/// local practice feedback only, no Career Passport scoring or evidence
/// wiring yet; that's an explicitly separate, later slice).
class WarehouseClipsSection extends ConsumerWidget {
  const WarehouseClipsSection({super.key});

  static const _domainOrder = [
    MicroLessonDomain.receiving,
    MicroLessonDomain.inspection,
    MicroLessonDomain.putAway,
    MicroLessonDomain.processing,
    MicroLessonDomain.picking,
    MicroLessonDomain.dispatch,
    MicroLessonDomain.delivery,
    MicroLessonDomain.supervisor,
    MicroLessonDomain.inventory,
    MicroLessonDomain.safety,
  ];

  static String _domainLabel(MicroLessonDomain domain) => switch (domain) {
    MicroLessonDomain.receiving => 'Receiving',
    MicroLessonDomain.inspection => 'Inspection',
    MicroLessonDomain.putAway => 'Put-away',
    MicroLessonDomain.processing => 'Processing',
    MicroLessonDomain.picking => 'Picking',
    MicroLessonDomain.dispatch => 'Dispatch',
    MicroLessonDomain.delivery => 'Delivery',
    MicroLessonDomain.supervisor => 'Supervisor / returns',
    MicroLessonDomain.inventory => 'Inventory',
    MicroLessonDomain.safety => 'Safety',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(microLessonClipControllerProvider);
    final pack = ref.watch(activeSectorPackProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Warehouse process clips',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          '10-second real-process clips: what to notice, what to decide, and a quick practice question.',
        ),
        const SizedBox(height: AppSpacing.sm),
        const NotEmployerEvidenceBanner(),
        const SizedBox(height: AppSpacing.md),
        state.when(
          loading: () => const _ClipsLoadingView(),
          error: (error, stackTrace) => AppErrorState(
            title: 'Clips could not be loaded',
            message: error is AppFailure
                ? error.message
                : 'The clip catalogue is temporarily unavailable.',
            onAction: () =>
                ref.read(microLessonClipControllerProvider.notifier).retry(),
          ),
          data: (data) {
            if (data.clips.isEmpty) {
              return const AppEmptyState(
                title: 'No clips yet',
                message:
                    'Warehouse process clips will appear here once published.',
              );
            }
            final populatedDomains = _domainOrder
                .where((domain) => data.clipsForDomain(domain).isNotEmpty)
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final domain in populatedDomains)
                  _DomainGroup(
                    pack: pack,
                    domain: domain,
                    label: _domainLabel(domain),
                    clips: data.clipsForDomain(domain),
                    viewedClipIds: data.viewedClipIds,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DomainGroup extends StatelessWidget {
  const _DomainGroup({
    required this.pack,
    required this.domain,
    required this.label,
    required this.clips,
    required this.viewedClipIds,
  });

  final SectorPack pack;
  final MicroLessonDomain domain;
  final String label;
  final List<MicroLessonClip> clips;
  final Set<String> viewedClipIds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final clip in clips) ...[
            _ClipRow(
              pack: pack,
              clip: clip,
              viewed: viewedClipIds.contains(clip.id),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// One process clip, styled with the same visual language as
/// `SectorIndexRow` (`SectorPackTypography` + `SectorIcon` + `pack`
/// colours) rather than reusing that widget directly -- a clip has no
/// natural "L-01"-style index the way a lesson unit does, so the left-edge
/// index tag that widget's contract requires doesn't fit here. This stays
/// a lighter, screen-specific row rather than a fifth shared structural
/// widget, per docs/adr/0020-sector-pack-abstraction.md.
///
/// No `Row(crossAxisAlignment: stretch)` / `IntrinsicHeight` here -- this
/// row has no full-height side element to stretch, so the bug class noted
/// in `sector_index_row.dart`'s doc comment (and this session's
/// dogfooding log) doesn't apply, but the same caution against them holds
/// for anything added here later.
class _ClipRow extends StatelessWidget {
  const _ClipRow({
    required this.pack,
    required this.clip,
    required this.viewed,
  });

  final SectorPack pack;
  final MicroLessonClip clip;

  /// Persisted on-device once playback reaches the end -- see
  /// `MicroLessonClipController.markViewed`.
  final bool viewed;

  @override
  Widget build(BuildContext context) {
    final hasVideo = clip.hasVideoAsset;
    final ink = Theme.of(context).colorScheme.onSurface;
    final inkSoft = Theme.of(context).colorScheme.onSurfaceVariant;
    final statusText = hasVideo
        ? '${clip.durationSeconds}s · ${clip.processArea} · Downloaded'
              '${viewed ? ' · Watched' : ''}'
        : 'Video not yet available · ${clip.processArea}';
    final statusColor = viewed ? pack.signalPalette.cleared : inkSoft;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Pushed on the root navigator, not the Learn tab's own nested
          // one (StatefulShellRoute gives each tab its own navigator) --
          // pushing on the tab's navigator left the shell's persistent
          // "AI Coach" FAB floating on top of the clip detail screen,
          // intercepting taps near the bottom of the page instead of
          // reaching real content.
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => MicroLessonPlayerScreen(
                clip: clip,
                onBack: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                _ClipThumbnail(pack: pack, clip: clip, viewed: viewed),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.title,
                        style: SectorPackTypography.bodyBold(color: ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: SectorPackTypography.monoLabel(
                          color: statusColor,
                          fontWeight: viewed
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SectorIcon(
                  glyph: SectorGlyph.chevronRight,
                  color: inkSoft,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Real thumbnail (generated by scripts/micro_lesson_video_pipeline.py)
/// when the clip has one, falling back to a drawn [SectorIcon] otherwise
/// -- covers both "video not produced yet" and, defensively, a video that
/// exists without a thumbnail (e.g. the pipeline hasn't been re-run yet).
/// A watched clip shows the check glyph regardless of thumbnail
/// availability, mirroring `SectorIndexRow`'s completed-lesson treatment.
class _ClipThumbnail extends StatelessWidget {
  const _ClipThumbnail({
    required this.pack,
    required this.clip,
    required this.viewed,
  });

  final SectorPack pack;
  final MicroLessonClip clip;
  final bool viewed;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = clip.thumbnailUrl;
    if (thumbnailUrl != null && thumbnailUrl.startsWith('asset://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          thumbnailUrl.substring('asset://'.length),
          width: 34,
          height: 34,
          fit: BoxFit.cover,
        ),
      );
    }
    final hasVideo = clip.hasVideoAsset;
    final glyph = viewed
        ? SectorGlyph.check
        : hasVideo
        ? SectorGlyph.play
        : SectorGlyph.pending;
    final color = viewed
        ? pack.signalPalette.cleared
        : hasVideo
        ? pack.primaryAccent
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
      ),
      child: SectorIcon(glyph: glyph, color: color, size: 16),
    );
  }
}

class _ClipsLoadingView extends StatelessWidget {
  const _ClipsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppSkeleton(height: 56),
        SizedBox(height: AppSpacing.sm),
        AppSkeleton(height: 56),
        SizedBox(height: AppSpacing.sm),
        AppSkeleton(height: 56),
      ],
    );
  }
}
