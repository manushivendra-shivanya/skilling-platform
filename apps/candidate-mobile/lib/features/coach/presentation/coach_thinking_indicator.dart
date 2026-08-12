import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

/// The shared "coach is composing a reply right now" visual: a small
/// spinner plus "Coach is typing…" copy, announced once via a live
/// [Semantics] region. `CoachThreadScreen` (mid-conversation, inside its
/// own message-bubble `Container`) and `AskCoachAffordance`'s quick-ask
/// sheet (inline, no bubble chrome) both used to hand-roll their own copy
/// of this same spinner-plus-text pair; this is the one implementation
/// both now share.
///
/// This is deliberately just the spinner + text, not the bubble shape
/// around it -- the bubble is `CoachThreadScreen`'s own message-list
/// chrome (the same `Container`/`BorderRadius`/`AppShadows.card` every
/// coach-side message bubble uses there), not part of what "the coach is
/// thinking" itself looks like. Note this is a different state entirely
/// from `CoachThreadsScreen`'s page-level loading spinner (that one means
/// "the thread list hasn't loaded yet", not "the coach is replying") --
/// that spinner became `AppLoadingProgressBar` separately rather than
/// folding in here.
class CoachThinkingIndicator extends StatelessWidget {
  const CoachThinkingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Coach is typing a reply',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Coach is typing…', style: TextStyle(color: AppColors.ink)),
        ],
      ),
    );
  }
}
