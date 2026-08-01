import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/micro_lesson_clip.dart';
import 'micro_lesson_clip_controller.dart';

/// Minimal dev-tools list of the shipped micro-lesson catalogue, grouped by
/// domain, so [MicroLessonPlayerScreen] has somewhere real to be reached
/// from. Not the real Learning/Practice tab entry point -- that wiring
/// (plus Learn/Practice/Assessment modes) is a separate, larger step.
class MicroLessonCatalogueScreen extends ConsumerWidget {
  const MicroLessonCatalogueScreen({
    required this.onOpenClip,
    required this.onBack,
    super.key,
  });

  final void Function(MicroLessonClip clip) onOpenClip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(microLessonClipControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Micro-lessons (dev)'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (data) => ListView(
          children: [
            for (final domain in MicroLessonDomain.values)
              if (data.clipsForDomain(domain).isNotEmpty)
                _DomainSection(
                  domain: domain,
                  clips: data.clipsForDomain(domain),
                  onOpenClip: onOpenClip,
                ),
          ],
        ),
      ),
    );
  }
}

class _DomainSection extends StatelessWidget {
  const _DomainSection({
    required this.domain,
    required this.clips,
    required this.onOpenClip,
  });

  final MicroLessonDomain domain;
  final List<MicroLessonClip> clips;
  final void Function(MicroLessonClip clip) onOpenClip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            domain.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final clip in clips)
          ListTile(
            leading: Icon(
              clip.videoUrl != null
                  ? Icons.play_circle_outline
                  : Icons.hourglass_empty,
            ),
            title: Text(clip.title),
            subtitle: Text(
              clip.videoUrl != null
                  ? '${clip.durationSeconds}s · ${clip.processArea}'
                  : 'Video not yet produced',
            ),
            onTap: () => onOpenClip(clip),
          ),
      ],
    );
  }
}
