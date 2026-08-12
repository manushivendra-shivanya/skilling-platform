import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/reduced_motion.dart';
import '../domain/coach_message.dart';
import 'coach_threads_controller.dart';

/// A muted, sage-leaning variant of [AppColors.brand] used only as the
/// *starting* point of a candidate bubble's colour warm-up (see
/// [_candidateBubbleColor]) -- not a new design-system token in its own
/// right, so it stays private here rather than joining `AppColors`.
/// Validated in "The Spark" interaction mock (published Artifact) using
/// this exact hex.
const _brandDim = Color(0xFF6F8F80);

/// One open conversation from `CoachThreadsScreen`'s list. Same message-
/// bubble UI the old single-conversation `CoachScreen` used, now scoped
/// to a single [CoachThread] instead of one global list.
class CoachThreadScreen extends ConsumerStatefulWidget {
  const CoachThreadScreen({required this.threadId, super.key});

  final String threadId;

  @override
  ConsumerState<CoachThreadScreen> createState() => _CoachThreadScreenState();
}

class _CoachThreadScreenState extends ConsumerState<CoachThreadScreen> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadsState = ref.watch(coachThreadsControllerProvider).valueOrNull;
    final thread = threadsState?.threadById(widget.threadId);
    final isSending =
        threadsState?.sendingThreadIds.contains(widget.threadId) ?? false;

    if (thread == null) {
      // Reached directly (e.g. a stale deep link) with no matching thread
      // -- rather than crash on a null lookup, show a plain not-found
      // state instead of a fabricated conversation.
      return Scaffold(
        appBar: AppBar(title: const Text('AI Career Coach')),
        body: const Center(child: Text('This conversation is not available.')),
      );
    }

    // Each candidate message's place in the conversation ("turn 1", "turn
    // 2", ...) -- drives how far along the accent warm-up
    // (_candidateBubbleColor) each of their own bubbles has settled.
    // Computed once per build rather than inline in the item builder so a
    // bubble doesn't need to re-scan everything before it on every frame.
    final candidateTurnByMessageId = <String, int>{};
    var candidateTurn = 0;
    for (final message in thread.messages) {
      if (message.author == CoachMessageAuthor.candidate) {
        candidateTurn += 1;
        candidateTurnByMessageId[message.id] = candidateTurn;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(thread.topicLabel)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: thread.messages.length + (isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == thread.messages.length) {
                    return const _MessageEntrance(
                      key: ValueKey('typing-indicator'),
                      child: _TypingIndicatorBubble(),
                    );
                  }
                  final message = thread.messages[index];
                  return _MessageEntrance(
                    key: ValueKey(message.id),
                    child: _MessageBubble(
                      message: message,
                      candidateTurn: candidateTurnByMessageId[message.id],
                    ),
                  );
                },
              ),
            ),
            Padding(
              // Bottom inset is deliberately just AppSpacing.sm, not
              // MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm.
              // `context` here is this State's own build context, which
              // sits *above* the Scaffold this method returns -- Scaffold
              // only strips the keyboard inset from the MediaQuery its
              // body subtree sees, not from this outer context, so this
              // read the full, un-stripped keyboard height. Meanwhile the
              // Scaffold (default resizeToAvoidBottomInset: true) already
              // shrinks the body by that same height, so adding it again
              // here double-counted it -- confirmed via a widget test that
              // reproduces "RenderFlex overflowed" with this term present
              // and a realistic keyboard height, matching the real-device
              // report (see coach_thread_screen_test.dart, and
              // coach_threads_screen.dart's identical fix).
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      enabled: !isSending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about skills or interviews',
                        labelText: 'Message',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _SendSparkButton(enabled: !isSending, onSend: _send),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _composer.text;
    if (text.trim().isEmpty) {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      ref
          .read(coachThreadsControllerProvider.notifier)
          .sendMessage(widget.threadId, text),
    );
    _composer.clear();
  }
}

/// Fades and slides a new message bubble in as it's added -- same pattern
/// as `SimulationScreenReveal`
/// (workplace_simulation/presentation/widgets/simulation_section_card.dart),
/// kept as a small screen-scoped copy rather than a shared import: Coach
/// has no dependency on the workplace-simulation feature otherwise, and a
/// one-message-bubble entrance isn't worth a cross-feature coupling for.
/// Respects the OS "reduce motion" setting via the shared
/// `forwardUnlessReducedMotion` (see core/widgets/reduced_motion.dart).
class _MessageEntrance extends StatefulWidget {
  const _MessageEntrance({required this.child, super.key});

  final Widget child;

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _opacity = curve;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.forwardUnlessReducedMotion(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      alwaysIncludeSemantics: true,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// The candidate's own bubble colour, warmed from [_brandDim] towards the
/// full [AppColors.brand] as the conversation goes on -- turn 1 reads
/// closer to a dim, sage-leaning green; by turn ~8 it's fully settled into
/// the brand colour. Meant to read as momentum building, not a mode
/// switch -- see "The Spark" mock's "the accent warms up" material.
/// [candidateTurn] is 1-indexed and only meaningful for candidate
/// messages; coach bubbles never call this.
Color _candidateBubbleColor(int? candidateTurn) {
  const base = 0.15;
  const perTurn = 0.12;
  final turn = candidateTurn ?? 1;
  final warmth = (base + (turn - 1) * perTurn).clamp(0.0, 1.0);
  return Color.lerp(_brandDim, AppColors.brand, warmth)!;
}

/// Send button for the Coach composer: a short radial spark burst (hot
/// [AppColors.highlight] core cooling to [AppColors.accent] embers) plus a
/// quick squash-and-stretch pulse, fired on every send -- "a spark catches
/// instead of a drop landing." Both existing app tokens; nothing new added
/// to the palette. See "The Spark" mock's "spark, not a ripple" material.
///
/// Skips the burst and pulse entirely under reduce-motion
/// (`prefersReducedMotion`) -- sending still works exactly the same, it
/// just appears instantly instead of animating.
class _SendSparkButton extends StatefulWidget {
  const _SendSparkButton({required this.enabled, required this.onSend});

  final bool enabled;
  final VoidCallback onSend;

  @override
  State<_SendSparkButton> createState() => _SendSparkButtonState();
}

class _SendSparkButtonState extends State<_SendSparkButton>
    with TickerProviderStateMixin {
  static const _burstDuration = Duration(milliseconds: 550);
  static const _pulseDuration = Duration(milliseconds: 420);

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: _burstDuration,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );
  final _random = math.Random();
  List<_SparkParticle> _particles = const [];

  @override
  void dispose() {
    _burst.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _fire() {
    widget.onSend();
    if (prefersReducedMotion(context)) {
      return;
    }
    setState(() {
      _particles = List.generate(22, (_) {
        final angle = _random.nextDouble() * math.pi * 2;
        final hot = _random.nextDouble() < 0.4;
        return _SparkParticle(
          angle: angle,
          distance: 22 + _random.nextDouble() * 26,
          size: (hot ? 3.0 : 2.0) + _random.nextDouble() * 1.4,
          color: hot ? AppColors.highlight : AppColors.accent,
          // Fraction of the controller's own duration this particle lives
          // for -- staggers when individual sparks die out instead of all
          // 22 vanishing on the same frame.
          lifeFraction: 0.55 + _random.nextDouble() * 0.45,
        );
      });
    });
    _burst
      ..stop()
      ..reset()
      ..forward();
    _pulse
      ..stop()
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Particles paint outside the button's own 48x48 bounds (they
          // travel outward from its centre), so this needs to be allowed
          // to overflow -- an OverflowBox reports its constrained 48x48
          // size upward regardless, so it never changes the composer
          // Row's layout.
          IgnorePointer(
            child: OverflowBox(
              maxWidth: 140,
              maxHeight: 140,
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) => CustomPaint(
                  painter: _SparkBurstPainter(
                    progress: _burst.value,
                    particles: _particles,
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseScale(_pulse.value),
                child: child,
              );
            },
            child: IconButton(
              tooltip: 'Send message',
              onPressed: widget.enabled ? _fire : null,
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }

  /// A quick squash-then-overshoot-then-settle, matching the mock's
  /// `send-pulse` keyframes (scale 1 -> 0.86 -> 1.1 -> 1).
  double _pulseScale(double t) {
    if (t < 0.3) {
      return ui.lerpDouble(1, 0.86, t / 0.3)!;
    }
    if (t < 0.55) {
      return ui.lerpDouble(0.86, 1.1, (t - 0.3) / 0.25)!;
    }
    return ui.lerpDouble(1.1, 1, (t - 0.55) / 0.45)!;
  }
}

class _SparkParticle {
  const _SparkParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.lifeFraction,
  });

  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double lifeFraction;
}

class _SparkBurstPainter extends CustomPainter {
  const _SparkBurstPainter({required this.progress, required this.particles});

  final double progress;
  final List<_SparkParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty || progress <= 0) return;
    final center = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final particle in particles) {
      final local = (progress / particle.lifeFraction).clamp(0.0, 1.0);
      if (local >= 1) continue;
      final eased = Curves.easeOut.transform(local);
      final life = 1 - local;
      final offset = Offset(
        center.dx + math.cos(particle.angle) * particle.distance * eased,
        center.dy + math.sin(particle.angle) * particle.distance * eased,
      );
      paint.color = particle.color.withValues(alpha: life);
      canvas.drawCircle(offset, particle.size * life, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.candidateTurn});

  final CoachMessage message;

  /// This message's 1-indexed place among the candidate's own messages in
  /// the thread -- `null` for coach messages, which don't warm up.
  final int? candidateTurn;

  @override
  Widget build(BuildContext context) {
    final isCandidate = message.author == CoachMessageAuthor.candidate;
    return Align(
      alignment: isCandidate ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isCandidate
              ? _candidateBubbleColor(candidateTurn)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isCandidate
            ? Text(message.text, style: const TextStyle(color: Colors.white))
            : _InkRevealText(
                text: message.text,
                style: TextStyle(color: AppColors.ink),
              ),
      ),
    );
  }
}

/// Reveals a coach reply word by word, each one arriving blurred and pale
/// then resolving into full focus -- "replies soak in like ink" rather
/// than a typewriter effect. See "The Spark" mock's "replies soak in"
/// material. Plays once per message (the same "animate on first build
/// only" shape as `_MessageEntranceState`) and is skipped entirely under
/// reduce-motion, landing at the fully-revealed state immediately.
///
/// The individual per-word `Text` widgets are excluded from the semantics
/// tree in favour of one `Semantics` label carrying the whole sentence --
/// a screen reader should hear "Pick one real example...", not four
/// separately-announced word fragments.
class _InkRevealText extends StatefulWidget {
  const _InkRevealText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_InkRevealText> createState() => _InkRevealTextState();
}

class _InkRevealTextState extends State<_InkRevealText>
    with SingleTickerProviderStateMixin {
  static const _staggerMs = 55;
  static const _wordDurationMs = 480;

  late final List<String> _words = widget.text
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalDurationMs),
  );
  bool _started = false;

  int get _totalDurationMs => _words.length <= 1
      ? _wordDurationMs
      : (_words.length - 1) * _staggerMs + _wordDurationMs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.forwardUnlessReducedMotion(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_words.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Wrap(
              children: [for (var i = 0; i < _words.length; i++) _word(i)],
            );
          },
        ),
      ),
    );
  }

  Widget _word(int index) {
    final total = _totalDurationMs;
    final startMs = index * _staggerMs;
    final localT = ((_controller.value * total - startMs) / _wordDurationMs)
        .clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(localT);
    final blurSigma = (1 - eased) * 2.4;
    Widget word = Text('${_words[index]} ', style: widget.style);
    if (blurSigma > 0.01) {
      word = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: word,
      );
    }
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 2),
        child: word,
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Semantics(
          liveRegion: true,
          label: 'Coach is typing a reply',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Coach is typing…', style: TextStyle(color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
