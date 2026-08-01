import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../domain/micro_lesson_clip.dart';

/// Minimal playback shell for a single [MicroLessonClip] (dev-tools only,
/// task following the micro-lesson content foundation): proves a clip can
/// actually be watched end to end. Deliberately does not show the
/// assessment question or record any evidence -- that wiring needs the
/// scoring/Career Passport mapping decision Codex flagged as a separate,
/// explicitly-approved step.
///
/// Handles both loading strategies a [MicroLessonClip.videoUrl] can carry:
/// an `asset://` URI (today's bundled starter clips) or a plain `http(s)://`
/// URI (the eventual Supabase-Storage-hosted catalogue), so this doesn't
/// need rework when clips move off the app bundle.
class MicroLessonPlayerScreen extends StatefulWidget {
  const MicroLessonPlayerScreen({
    required this.clip,
    required this.onBack,
    super.key,
  });

  final MicroLessonClip clip;
  final VoidCallback onBack;

  @override
  State<MicroLessonPlayerScreen> createState() =>
      _MicroLessonPlayerScreenState();
}

class _MicroLessonPlayerScreenState extends State<MicroLessonPlayerScreen> {
  VideoPlayerController? _controller;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final url = widget.clip.videoUrl;
    if (url == null) return;

    final controller = url.startsWith('asset://')
        ? VideoPlayerController.asset(url.substring('asset://'.length))
        : VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _loadError = '$error');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(clip.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _buildVideoArea()),
          const SizedBox(height: 16),
          Text(clip.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text(
            'What to look for',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(clip.expectedObservation),
          const SizedBox(height: 12),
          Text('Transcript', style: Theme.of(context).textTheme.titleSmall),
          Text(clip.transcript),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    final controller = _controller;
    if (widget.clip.videoUrl == null) {
      // No clip produced yet for this catalogue entry -- a real state, not
      // an error, so it gets a plain placeholder rather than an error banner.
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: Text('Video not yet available for this clip')),
      );
    }
    if (_loadError != null) {
      return ColoredBox(
        color: Colors.black12,
        child: Center(child: Text('Playback failed: $_loadError')),
      );
    }
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () =>
          controller.value.isPlaying ? controller.pause() : controller.play(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(controller),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.isPlaying
                ? const SizedBox.shrink()
                : const Icon(Icons.play_arrow, size: 56, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
