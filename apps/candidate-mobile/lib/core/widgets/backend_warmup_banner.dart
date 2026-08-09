import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../network/backend_warmup_controller.dart';
import 'app_card.dart';

/// Watching this provider is what actually fires the warm-up ping (see
/// [BackendWarmupController].build) -- placing this widget on the sign-in
/// screen both triggers the ping and shows a ticking status while it's in
/// flight, so a candidate hitting a cold Render Free instance sees "this
/// is working, not stuck" instead of a silent multi-second wait right
/// before their first real request.
///
/// Shows nothing for the common warm-instance case (settles well inside
/// [_gracePeriod]) and nothing at all once the ping settles, success or
/// not -- a genuinely unreachable backend is still the next screen's job
/// to report, not this banner's.
class BackendWarmupBanner extends ConsumerStatefulWidget {
  const BackendWarmupBanner({super.key});

  static const _gracePeriod = Duration(seconds: 1);

  @override
  ConsumerState<BackendWarmupBanner> createState() =>
      _BackendWarmupBannerState();
}

class _BackendWarmupBannerState extends ConsumerState<BackendWarmupBanner> {
  // Deliberately Timer-driven throughout, not Stopwatch/DateTime -- a
  // Stopwatch measures real wall-clock time, which does not advance
  // together with `tester.pump(duration)`'s fake-async clock in widget
  // tests, whereas Timer callbacks do.
  Timer? _graceTimer;
  Timer? _ticker;
  bool _isPastGracePeriod = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _graceTimer = Timer(BackendWarmupBanner._gracePeriod, () {
      if (mounted) setState(() => _isPastGracePeriod = true);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warmup = ref.watch(backendWarmupControllerProvider);

    if (!warmup.isLoading || !_isPastGracePeriod) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        backgroundColor: AppColors.infoSoft,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Getting things ready — first load can take up to a '
                'minute today (${_elapsedSeconds}s)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
