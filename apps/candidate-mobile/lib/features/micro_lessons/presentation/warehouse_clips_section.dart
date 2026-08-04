import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
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
                    domain: domain,
                    label: _domainLabel(domain),
                    clips: data.clipsForDomain(domain),
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
    required this.domain,
    required this.label,
    required this.clips,
  });

  final MicroLessonDomain domain;
  final String label;
  final List<MicroLessonClip> clips;

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
            _ClipTile(clip: clip),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({required this.clip});

  final MicroLessonClip clip;

  @override
  Widget build(BuildContext context) {
    final hasVideo = clip.hasVideoAsset;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Pushed on the root navigator, not the Learn tab's own nested one
        // (StatefulShellRoute gives each tab its own navigator) -- pushing
        // on the tab's navigator left the shell's persistent "AI Coach"
        // FAB floating on top of the clip detail screen, intercepting taps
        // near the bottom of the page instead of reaching real content.
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
              _ClipThumbnail(clip: clip),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clip.title),
                    Text(
                      hasVideo
                          ? '${clip.durationSeconds}s • ${clip.processArea} • Downloaded'
                          : 'Video not yet available • ${clip.processArea}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real thumbnail (generated by scripts/micro_lesson_video_pipeline.py)
/// when the clip has one, falling back to a plain icon otherwise --
/// covers both "video not produced yet" and, defensively, a video that
/// exists without a thumbnail (e.g. the pipeline hasn't been re-run yet).
class _ClipThumbnail extends StatelessWidget {
  const _ClipThumbnail({required this.clip});

  final MicroLessonClip clip;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = clip.thumbnailUrl;
    if (thumbnailUrl != null && thumbnailUrl.startsWith('asset://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          thumbnailUrl.substring('asset://'.length),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    final hasVideo = clip.hasVideoAsset;
    return Icon(
      hasVideo ? Icons.play_circle_outline : Icons.hourglass_empty,
      color: hasVideo
          ? AppColors.brand
          : Theme.of(context).colorScheme.onSurfaceVariant,
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
