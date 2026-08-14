import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../l10n/generated/app_localizations.dart';
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
  const WarehouseClipsSection({this.onOpenSimulation, super.key});

  /// Opens the matching Workplace Simulation mission for a clip that has
  /// one (Receiving/Inspection -> receiving, Put-away -> put-away) -- null
  /// when the caller has no simulation entry point wired (e.g. embedded
  /// somewhere the Practise handoff doesn't make sense), in which case the
  /// handoff button in [_ClipRow] simply doesn't render.
  final ValueChanged<String>? onOpenSimulation;

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

  static String _domainLabel(MicroLessonDomain domain, AppLocalizations l10n) =>
      switch (domain) {
        MicroLessonDomain.receiving => l10n.clipDomainReceiving,
        MicroLessonDomain.inspection => l10n.clipDomainInspection,
        MicroLessonDomain.putAway => l10n.clipDomainPutAway,
        MicroLessonDomain.processing => l10n.clipDomainProcessing,
        MicroLessonDomain.picking => l10n.clipDomainPicking,
        MicroLessonDomain.dispatch => l10n.clipDomainDispatch,
        MicroLessonDomain.delivery => l10n.clipDomainDelivery,
        MicroLessonDomain.supervisor => l10n.clipDomainSupervisor,
        MicroLessonDomain.inventory => l10n.clipDomainInventory,
        MicroLessonDomain.safety => l10n.clipDomainSafety,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(microLessonClipControllerProvider);
    final pack = ref.watch(activeSectorPackProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.clipsHeadline,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.clipsSubtitle),
        const SizedBox(height: AppSpacing.sm),
        const NotEmployerEvidenceBanner(),
        const SizedBox(height: AppSpacing.md),
        state.when(
          loading: () => const _ClipsLoadingView(),
          error: (error, stackTrace) => AppErrorState(
            title: l10n.clipsLoadErrorTitle,
            message: error is AppFailure
                ? error.localizedMessage(l10n)
                : l10n.clipsLoadErrorFallback,
            onAction: () =>
                ref.read(microLessonClipControllerProvider.notifier).retry(),
          ),
          data: (data) {
            if (data.clips.isEmpty) {
              return AppEmptyState(
                title: l10n.clipsEmptyTitle,
                message: l10n.clipsEmptyMessage,
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
                    label: _domainLabel(domain, l10n),
                    clips: data.clipsForDomain(domain),
                    viewedClipIds: data.viewedClipIds,
                    onOpenSimulation: onOpenSimulation,
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
    required this.onOpenSimulation,
  });

  final SectorPack pack;
  final MicroLessonDomain domain;
  final String label;
  final List<MicroLessonClip> clips;
  final Set<String> viewedClipIds;
  final ValueChanged<String>? onOpenSimulation;

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
              onOpenSimulation: onOpenSimulation,
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
    required this.onOpenSimulation,
  });

  final SectorPack pack;
  final MicroLessonClip clip;

  /// Persisted on-device once playback reaches the end -- see
  /// `MicroLessonClipController.markViewed`.
  final bool viewed;

  final ValueChanged<String>? onOpenSimulation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasVideo = clip.hasVideoAsset;
    final ink = Theme.of(context).colorScheme.onSurface;
    final inkSoft = Theme.of(context).colorScheme.onSurfaceVariant;
    final statusText = !hasVideo
        ? l10n.clipStatusNoVideo(clip.processArea)
        : viewed
        ? l10n.clipStatusDownloadedWatched(
            clip.durationSeconds,
            clip.processArea,
          )
        : l10n.clipStatusDownloaded(clip.durationSeconds, clip.processArea);
    final statusColor = viewed ? pack.signalPalette.cleared : inkSoft;
    final simulation = _simulationForClip(clip, l10n);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              // Pushed on the root navigator, not the Learn tab's own
              // nested one (StatefulShellRoute gives each tab its own
              // navigator) -- pushing on the tab's navigator left the
              // shell's persistent "AI Coach" FAB floating on top of the
              // clip detail screen, intercepting taps near the bottom of
              // the page instead of reaching real content.
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => MicroLessonPlayerScreen(
                    clip: clip,
                    onBack: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
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
            // Direct handoff into the matching Workplace Simulation mission
            // -- only for the clips that actually have one (Receiving,
            // Inspection, Put-away today), and only when the caller wired a
            // simulation entry point at all.
            if (simulation != null && onOpenSimulation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => onOpenSimulation!(simulation.missionId),
                    icon: const Icon(Icons.precision_manufacturing_outlined),
                    label: Text(l10n.clipPractiseSimulation(simulation.label)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which Workplace Simulation mission (if any) reinforces this clip's
/// domain -- see `WorkplaceSimulationController`'s mission IDs. Only
/// wired for the domains that currently have a matching mission; every
/// other domain returns null and the handoff button doesn't render.
class _SimulationLink {
  const _SimulationLink({required this.label, required this.missionId});

  final String label;
  final String missionId;
}

_SimulationLink? _simulationForClip(
  MicroLessonClip clip,
  AppLocalizations l10n,
) {
  return switch (clip.domain) {
    MicroLessonDomain.receiving ||
    MicroLessonDomain.inspection => _SimulationLink(
      label: l10n.clipDomainReceiving,
      missionId: 'receive-incoming-shipment-01',
    ),
    MicroLessonDomain.putAway => _SimulationLink(
      label: l10n.clipDomainPutAway,
      missionId: 'put-away-incoming-stock-01',
    ),
    _ => null,
  };
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
