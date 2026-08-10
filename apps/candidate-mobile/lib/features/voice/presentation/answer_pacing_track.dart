import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';

/// How long a good answer runs. The introduction question already tells the
/// candidate "1-2 मिनट में", and this is that instruction made visible while
/// they speak instead of remembered from the previous screen.
const answerTargetStart = Duration(seconds: 60);
const answerTargetEnd = Duration(seconds: 120);
const _trackFullScale = Duration(seconds: 180);

/// Where the answer currently sits against the target window.
enum AnswerPace {
  tooShort,
  onTarget,
  runningLong;

  static AnswerPace of(Duration elapsed) {
    if (elapsed < answerTargetStart) return AnswerPace.tooShort;
    if (elapsed <= answerTargetEnd) return AnswerPace.onTarget;
    return AnswerPace.runningLong;
  }
}

/// A length gauge for a spoken answer.
///
/// Deliberately not a waveform: the capture layer exposes no amplitude, so a
/// moving waveform here would be animation pretending to be data. Length is
/// something we genuinely know and, for interview practice, the thing worth
/// coaching -- an under-30-second introduction and a four-minute ramble fail
/// for opposite reasons, and neither is obvious to someone practising alone.
///
/// Colour is never the only channel: the band is drawn, the figure is written,
/// and the label states the same thing in words.
class AnswerPacingTrack extends StatelessWidget {
  const AnswerPacingTrack({required this.elapsed, super.key});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final pace = AnswerPace.of(elapsed);
    final (color, label) = switch (pace) {
      AnswerPace.tooShort => (AppColors.inkMuted, 'Thoda aur boliye'),
      AnswerPace.onTarget => (AppColors.success, 'Bilkul sahi lambai'),
      AnswerPace.runningLong => (AppColors.warning, 'Ab samet lijiye'),
    };

    final total = _trackFullScale.inSeconds;
    final progress = (elapsed.inSeconds / total).clamp(0.0, 1.0);
    final bandStart = answerTargetStart.inSeconds / total;
    final bandEnd = answerTargetEnd.inSeconds / total;

    return Semantics(
      liveRegion: true,
      label:
          'Recording ${_spoken(elapsed)}. $label. '
          'Target one to two minutes.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _clock(elapsed),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  // Digits must not reflow as the seconds tick over.
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 14,
                child: Stack(
                  children: [
                    // Full track.
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    // The target window, drawn so the goal is visible before
                    // the answer reaches it.
                    Positioned(
                      left: width * bandStart,
                      width: width * (bandEnd - bandStart),
                      top: 0,
                      bottom: 0,
                      child: Container(color: AppColors.successSoft),
                    ),
                    // Elapsed.
                    Positioned(
                      left: 0,
                      width: width * progress,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0:00', style: _tick(context)),
              Text('target 1:00 – 2:00', style: _tick(context)),
              Text('3:00', style: _tick(context)),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle? _tick(BuildContext context) => Theme.of(
    context,
  ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted);

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  static String _spoken(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '$s seconds';
    return '$m minute${m == 1 ? '' : 's'} $s seconds';
  }
}
