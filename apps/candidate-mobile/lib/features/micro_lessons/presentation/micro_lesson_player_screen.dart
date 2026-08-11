import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/micro_lesson_assessment_attempt.dart';
import '../domain/micro_lesson_assessment_repository.dart';
import '../domain/micro_lesson_clip.dart';
import 'micro_lesson_clip_controller.dart';
import 'not_employer_evidence_banner.dart';

/// Clip detail + practice/assessment screen for a single [MicroLessonClip]
/// (micro-lessons v0.2). Two distinct interactions below the video:
/// - Tapping any answer option gives instant local feedback -- free,
///   unlimited, never recorded (see [NotEmployerEvidenceBanner]).
/// - "Submit for Career Passport evidence" records the *currently
///   selected* answer as a real, scored assessment attempt via
///   [MicroLessonAssessmentRepository], up to [maxAssessmentAttemptsPerClip]
///   times. Recording generates real evidence (see
///   `micro_lesson_evidence_generation_service.dart`) that flows into the
///   Career Passport -- it is still not employer evidence per se; it only
///   becomes visible to an employer if the candidate later shares it,
///   exactly like every other Career Passport entry.
///
/// Handles both loading strategies a [MicroLessonClip.videoUrl] can carry:
/// an `asset://` URI (today's bundled starter clips, offline-capable) or a
/// plain `http(s)://` URI (the eventual Supabase-Storage-hosted
/// catalogue), so this doesn't need rework when clips move off the app
/// bundle.
class MicroLessonPlayerScreen extends ConsumerStatefulWidget {
  const MicroLessonPlayerScreen({
    required this.clip,
    required this.onBack,
    super.key,
  });

  final MicroLessonClip clip;
  final VoidCallback onBack;

  @override
  ConsumerState<MicroLessonPlayerScreen> createState() =>
      _MicroLessonPlayerScreenState();
}

class _MicroLessonPlayerScreenState
    extends ConsumerState<MicroLessonPlayerScreen> {
  VideoPlayerController? _controller;
  String? _loadError;
  String? _selectedAnswerId;

  // The clip loops, so "finished" isn't a one-shot event -- this listener
  // fires on every position tick regardless, and the flag just makes the
  // actual markViewed call (and its controller-state write) happen once.
  bool _hasMarkedViewed = false;

  // null while the existing attempt count is still loading.
  int? _attemptsUsed;
  MicroLessonAssessmentAttempt? _lastSubmittedAttempt;
  String? _submissionError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initController();
    _loadAttemptsUsed();
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
      controller.addListener(_onPositionChanged);
      await controller.play();
      if (!mounted) {
        controller.removeListener(_onPositionChanged);
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _loadError = '$error');
    }
  }

  // Near-end rather than exact-end: a looping controller's position can
  // skip past the final frame straight to the next loop's start between
  // ticks, so waiting for position == duration risks missing the moment
  // entirely on a fast device.
  void _onPositionChanged() {
    if (_hasMarkedViewed) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration == Duration.zero) return;
    if (position < duration - const Duration(milliseconds: 300)) return;
    _hasMarkedViewed = true;
    ref
        .read(microLessonClipControllerProvider.notifier)
        .markViewed(widget.clip.id);
  }

  Future<void> _loadAttemptsUsed() async {
    final candidateId = await _readCandidateId();
    if (candidateId == null) {
      if (mounted) setState(() => _attemptsUsed = 0);
      return;
    }
    final result = await ref
        .read(microLessonAssessmentRepositoryProvider)
        .listAttempts(candidateId);
    final used = result.when(
      success: (attempts) =>
          attempts.where((attempt) => attempt.clipId == widget.clip.id).length,
      failure: (_) => 0,
    );
    if (mounted) setState(() => _attemptsUsed = used);
  }

  Future<String?> _readCandidateId() async {
    final result = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = result.when(
      success: (value) => value,
      failure: (_) => null,
    );
    return session?.isAuthenticated == true ? session!.candidateId : null;
  }

  Future<void> _submitAssessment() async {
    final answerId = _selectedAnswerId;
    if (answerId == null || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });
    final candidateId = await _readCandidateId();
    if (candidateId == null) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submissionError = 'Sign in again to record this attempt.';
        });
      }
      return;
    }
    final result = await ref
        .read(microLessonAssessmentRepositoryProvider)
        .recordAttempt(
          candidateId: candidateId,
          clip: widget.clip,
          selectedAnswerId: answerId,
        );
    if (!mounted) return;
    result.when(
      success: (attempt) => setState(() {
        _isSubmitting = false;
        _lastSubmittedAttempt = attempt;
        _attemptsUsed = (_attemptsUsed ?? 0) + 1;
      }),
      failure: (failure) => setState(() {
        _isSubmitting = false;
        _submissionError = failure.message;
      }),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPositionChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final titleStyle = Theme.of(context).textTheme.titleSmall;
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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Clips are shot vertically (720x1280, 9:16) -- forcing a 16:9
          // landscape box here squashed the picture instead of just
          // letterboxing it. The real aspect ratio also happens to be
          // close to a phone screen's own shape, so using it makes the
          // player read as a near-full-screen view rather than a small
          // thumbnail-sized box.
          AspectRatio(
            aspectRatio: _controller?.value.aspectRatio ?? 9 / 16,
            child: _buildVideoArea(),
          ),
          const SizedBox(height: AppSpacing.xs),
          _AssetStateLabel(clip: clip, hasError: _loadError != null),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${clip.role} • ${clip.processArea}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(clip.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          Text('What to look for', style: titleStyle),
          Text(clip.expectedObservation),
          const SizedBox(height: AppSpacing.sm),
          Text('What to decide', style: titleStyle),
          Text(clip.expectedDecision),
          const SizedBox(height: AppSpacing.sm),
          Text('Lesson', style: titleStyle),
          Text(clip.lessonContent),
          const SizedBox(height: AppSpacing.sm),
          Text('Transcript', style: titleStyle),
          Text(clip.transcript),
          const SizedBox(height: AppSpacing.xl),
          const NotEmployerEvidenceBanner(),
          const SizedBox(height: AppSpacing.md),
          _PracticeQuestion(
            clip: clip,
            selectedAnswerId: _selectedAnswerId,
            onSelect: (id) => setState(() => _selectedAnswerId = id),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          _AssessmentSubmission(
            selectedAnswerId: _selectedAnswerId,
            attemptsUsed: _attemptsUsed,
            lastSubmittedAttempt: _lastSubmittedAttempt,
            submissionError: _submissionError,
            isSubmitting: _isSubmitting,
            onSubmit: _submitAssessment,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    final controller = _controller;
    if (!widget.clip.hasVideoAsset) {
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

/// Small state label under the video area: video missing, playback error,
/// or (for a clip that does have a bundled clip) that it's a local,
/// offline-capable asset rather than a remote stream.
class _AssetStateLabel extends StatelessWidget {
  const _AssetStateLabel({required this.clip, required this.hasError});

  final MicroLessonClip clip;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (true) {
      _ when hasError => (
        Icons.error_outline,
        'Playback failed',
        AppColors.error,
      ),
      _ when !clip.hasVideoAsset => (
        Icons.hourglass_empty,
        'Video not yet produced for this clip',
        AppColors.inkMuted,
      ),
      _ when clip.videoUrl!.startsWith('asset://') => (
        Icons.download_done,
        'Bundled with the app • works offline',
        AppColors.success,
      ),
      _ => (Icons.cloud_outlined, 'Streamed', AppColors.info),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _PracticeQuestion extends StatelessWidget {
  const _PracticeQuestion({
    required this.clip,
    required this.selectedAnswerId,
    required this.onSelect,
  });

  final MicroLessonClip clip;
  final String? selectedAnswerId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = selectedAnswerId == null
        ? null
        : clip.answerOptions.firstWhere((o) => o.id == selectedAnswerId);
    final isCorrect = selected?.id == clip.correctAnswerId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          clip.assessmentQuestion,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final option in clip.answerOptions) ...[
          AppCard(
            onTap: () => onSelect(option.id),
            semanticLabel:
                '${option.label}. ${selectedAnswerId == option.id ? 'Selected' : 'Not selected'}',
            backgroundColor: selectedAnswerId == option.id
                ? AppColors.brandSoft
                : AppColors.surface,
            child: Row(
              children: [
                Expanded(child: Text(option.label)),
                Icon(
                  selectedAnswerId == option.id
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selectedAnswerId == option.id
                      ? AppColors.brand
                      : AppColors.outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (selected != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            backgroundColor: isCorrect
                ? AppColors.successSoft
                : AppColors.errorSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(selected.feedback)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The v0.2 addition: submits the currently selected answer as a real,
/// recorded assessment attempt (distinct from [_PracticeQuestion]'s free
/// instant feedback above, which never records anything).
class _AssessmentSubmission extends StatelessWidget {
  const _AssessmentSubmission({
    required this.selectedAnswerId,
    required this.attemptsUsed,
    required this.lastSubmittedAttempt,
    required this.submissionError,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final String? selectedAnswerId;
  final int? attemptsUsed;
  final MicroLessonAssessmentAttempt? lastSubmittedAttempt;
  final String? submissionError;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final used = attemptsUsed;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    if (used == null) {
      return Row(
        children: [
          Text('Assessment', style: titleStyle),
          const SizedBox(width: AppSpacing.sm),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }
    final remaining = maxAssessmentAttemptsPerClip - used;
    final lastAttempt = lastSubmittedAttempt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Assessment', style: titleStyle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Submitting counts toward your Career Passport evidence for this '
          'clip -- ${remaining.clamp(0, maxAssessmentAttemptsPerClip)} of '
          '$maxAssessmentAttemptsPerClip attempts remaining.',
        ),
        if (lastAttempt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            backgroundColor: lastAttempt.isCorrect
                ? AppColors.successSoft
                : AppColors.errorSoft,
            child: Row(
              children: [
                Icon(
                  lastAttempt.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: lastAttempt.isCorrect
                      ? AppColors.success
                      : AppColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    lastAttempt.isCorrect
                        ? 'Recorded -- correct answer.'
                        : 'Recorded -- incorrect answer.',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (remaining > 0)
          AppButton(
            label: isSubmitting
                ? 'Submitting...'
                : lastAttempt == null
                ? 'Submit for Career Passport evidence'
                : 'Submit another attempt',
            onPressed: (selectedAnswerId == null || isSubmitting)
                ? null
                : onSubmit,
          )
        else
          const Text('No attempts remaining for this clip.'),
        if (submissionError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            submissionError!,
            style: const TextStyle(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
