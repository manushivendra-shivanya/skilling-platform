import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_shadows.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_accent_pill.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_sticky_footer.dart';
import '../domain/shift_match.dart';
import '../domain/shifts_repository.dart';
import 'shifts_controller.dart';

/// "Shifts near you today" -- the real Shift tab, replacing the earlier
/// placeholder. Candidates browse published shifts, see a skill-match% for
/// each (computed client-side, see `deriveShiftMatch`), and accept one.
/// Check-in/out, availability, payouts, and grievances live behind CTAs
/// here rather than as separate bottom-nav tabs.
class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({
    required this.onOpenAvailability,
    required this.onOpenMyShifts,
    required this.onOpenPayouts,
    required this.onOpenGrievances,
    required this.onOpenSkillGap,
    super.key,
  });

  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenMyShifts;
  final VoidCallback onOpenPayouts;
  final VoidCallback onOpenGrievances;
  final VoidCallback onOpenSkillGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftsControllerProvider);
    return state.when(
      loading: () => const _ShiftLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: 'Shifts could not be loaded',
        message: error is AppFailure
            ? error.message
            : 'Shifts are temporarily unavailable.',
        onAction: () => ref.read(shiftsControllerProvider.notifier).retry(),
      ),
      data: (value) => _ShiftContent(
        state: value,
        onOpenAvailability: onOpenAvailability,
        onOpenMyShifts: onOpenMyShifts,
        onOpenPayouts: onOpenPayouts,
        onOpenGrievances: onOpenGrievances,
        onOpenSkillGap: onOpenSkillGap,
      ),
    );
  }
}

/// "Starts in Xh Ym" style label for a shift beginning soon, mirroring
/// `jobPostedLabel` (jobs_repository.dart)'s density but pointed at the
/// future instead of the past. Null whenever the shift isn't genuinely
/// starting soon -- already started, more than [window] away, or (rounds
/// to) under a minute out -- so the urgency ribbon this feeds never claims
/// urgency the data doesn't back up.
String? shiftUrgencyLabel(
  DateTime startsAt, {
  DateTime? now,
  Duration window = const Duration(hours: 6),
}) {
  final reference = now ?? DateTime.now();
  final diff = startsAt.difference(reference);
  if (diff.inMinutes <= 0 || diff > window) return null;
  final hours = diff.inMinutes ~/ 60;
  final minutes = diff.inMinutes % 60;
  final duration = switch ((hours, minutes)) {
    (0, final m) => '${m}m',
    (final h, 0) => '${h}h',
    (final h, final m) => '${h}h ${m}m',
  };
  return 'Starts in $duration';
}

class _ShiftContent extends ConsumerWidget {
  const _ShiftContent({
    required this.state,
    required this.onOpenAvailability,
    required this.onOpenMyShifts,
    required this.onOpenPayouts,
    required this.onOpenGrievances,
    required this.onOpenSkillGap,
  });

  final ShiftsState state;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenMyShifts;
  final VoidCallback onOpenPayouts;
  final VoidCallback onOpenGrievances;
  final VoidCallback onOpenSkillGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startingSoon = [...state.shifts]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final bestMatch = [...state.shifts]
      ..sort(
        (a, b) =>
            state.matchFor(b.id).matchPercent -
            state.matchFor(a.id).matchPercent,
      );
    final bestMatchShift = state.shifts.isEmpty ? null : bestMatch.first;
    final bestMatchApplication = bestMatchShift == null
        ? null
        : state.applicationFor(bestMatchShift.id);
    final bestMatchMatch = bestMatchShift == null
        ? null
        : state.matchFor(bestMatchShift.id);
    // The sticky footer and the bottom sheet it opens share this one
    // eligibility check -- not applied yet, and no missing competency --
    // so the two never disagree about whether the shift is acceptable.
    final showAcceptCta =
        bestMatchShift != null &&
        bestMatchApplication == null &&
        (bestMatchMatch?.isEligible ?? false);
    final urgencyLabel = bestMatchShift == null
        ? null
        : shiftUrgencyLabel(bestMatchShift.startsAt);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              showAcceptCta ? AppSpacing.lg : 112,
            ),
            children: [
              if (urgencyLabel != null) ...[
                _UrgencyRibbon(label: urgencyLabel),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'My Shift',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.isLiveData
                    ? '${state.shifts.length} shift${state.shifts.length == 1 ? '' : 's'} near you today'
                    : 'Demo shifts • No live employer connection',
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              _ShortcutStrip(
                onOpenAvailability: onOpenAvailability,
                onOpenMyShifts: onOpenMyShifts,
                onOpenPayouts: onOpenPayouts,
                onOpenGrievances: onOpenGrievances,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.shifts.isEmpty)
                const SizedBox(
                  height: 220,
                  child: AppEmptyState(
                    title: 'No shifts right now',
                    message:
                        'Check back soon, or set your availability so Flora knows when you can work.',
                  ),
                )
              else ...[
                Text(
                  'Best match',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ShiftCard(
                  shift: bestMatchShift!,
                  match: bestMatchMatch!,
                  application: bestMatchApplication,
                  isLiveData: state.isLiveData,
                  isHero: true,
                  onTap: () => _showShiftDetails(
                    context,
                    ref,
                    bestMatchShift,
                    onOpenSkillGap: onOpenSkillGap,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Starts soon',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final shift in startingSoon) ...[
                  _ShiftCard(
                    shift: shift,
                    match: state.matchFor(shift.id),
                    application: state.applicationFor(shift.id),
                    isLiveData: state.isLiveData,
                    onTap: () => _showShiftDetails(
                      context,
                      ref,
                      shift,
                      onOpenSkillGap: onOpenSkillGap,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              const AppCard(
                backgroundColor: AppColors.infoSoft,
                child: Text(
                  'Flora facilitates these shifts. Final attendance and payout '
                  'approval follows the company’s shift policy.',
                ),
              ),
            ],
          ),
        ),
        if (showAcceptCta)
          _AcceptShiftFooter(
            shift: bestMatchShift,
            onTap: () => _showShiftDetails(
              context,
              ref,
              bestMatchShift,
              onOpenSkillGap: onOpenSkillGap,
            ),
          ),
      ],
    );
  }

  Future<void> _showShiftDetails(
    BuildContext context,
    WidgetRef ref,
    Shift shift, {
    required VoidCallback onOpenSkillGap,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      title: shift.roleTitle,
      child: _ShiftDetails(
        shift: shift,
        match: state.matchFor(shift.id),
        application: state.applicationFor(shift.id),
        isLiveData: state.isLiveData,
        onOpenSkillGap: onOpenSkillGap,
        onAccept: () =>
            ref.read(shiftsControllerProvider.notifier).acceptShift(shift.id),
      ),
    );
  }
}

/// Small pill banner shown only when a real shift starts soon -- see
/// [shiftUrgencyLabel]. Uses the same accent tone the rest of the app
/// reserves for "pay attention now" chips (e.g. `TodayMissionCard`'s step
/// counter), applied here at banner scale.
class _UrgencyRibbon extends StatelessWidget {
  const _UrgencyRibbon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppAccentPill(
      icon: Icons.bolt_rounded,
      label: label,
      background: AppColors.accentSoft,
      foreground: AppColors.accent,
      iconSize: 18,
      fontWeight: FontWeight.w700,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.medium,
      expand: true,
    );
  }
}

/// The Availability / My shifts / Payouts / Support shortcuts as a
/// horizontally scrollable strip of icon "plates", one soft tone each --
/// same "colored plate + label underneath" language as Home's
/// `TodayServicesCarousel`, at a smaller, non-auto-scrolling scale since
/// there are only four of these and they're secondary to the shift list
/// below.
class _ShortcutStrip extends StatelessWidget {
  const _ShortcutStrip({
    required this.onOpenAvailability,
    required this.onOpenMyShifts,
    required this.onOpenPayouts,
    required this.onOpenGrievances,
  });

  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenMyShifts;
  final VoidCallback onOpenPayouts;
  final VoidCallback onOpenGrievances;

  static const _baseHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    // Same text-scale safeguard as TodayServicesCarousel: a fixed pixel
    // height overflows once the platform text scale grows the label below
    // the icon, so the strip's height keeps pace with it instead of
    // clipping.
    final textScale =
        MediaQuery.textScalerOf(context).scale(_baseHeight) / _baseHeight;
    return SizedBox(
      height: _baseHeight * textScale.clamp(1, 1.6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          AppIconPlateButton(
            icon: Icons.schedule_outlined,
            label: 'Availability',
            background: AppColors.brandSoft,
            foreground: AppColors.brand,
            onTap: onOpenAvailability,
          ),
          const SizedBox(width: AppSpacing.md),
          AppIconPlateButton(
            icon: Icons.event_note_outlined,
            label: 'My shifts',
            background: AppColors.infoSoft,
            foreground: AppColors.info,
            onTap: onOpenMyShifts,
          ),
          const SizedBox(width: AppSpacing.md),
          AppIconPlateButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payouts',
            background: AppColors.successSoft,
            foreground: AppColors.success,
            onTap: onOpenPayouts,
          ),
          const SizedBox(width: AppSpacing.md),
          AppIconPlateButton(
            icon: Icons.support_agent_outlined,
            label: 'Support',
            background: AppColors.warningSoft,
            foreground: AppColors.warning,
            onTap: onOpenGrievances,
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.match,
    required this.application,
    required this.isLiveData,
    required this.onTap,
    this.isHero = false,
  });

  final Shift shift;
  final ShiftMatch match;
  final ShiftApplication? application;
  final bool isLiveData;
  final VoidCallback onTap;

  /// True only for the single "Best match" card -- gives it a stronger
  /// shadow, roomier padding, and breaks the pay figure out into its own
  /// block at the bottom instead of sharing the title row. Every other
  /// card in this file keeps the plain (non-hero) styling below.
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                shift.roleTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!isHero)
              Text(
                '₹${shift.payAmount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text('${shift.siteName} • ${shift.siteAddress}'),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${timeFormat.format(shift.startsAt)} – ${timeFormat.format(shift.endsAt)}',
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (application != null)
              AppStatusChip(
                label: _statusLabel(application!.status),
                tone: _statusTone(application!.status),
              )
            else
              AppStatusChip(
                label: match.isEligible
                    ? 'You match: ${match.matchPercent}%'
                    : 'Skills needed',
                tone: match.isEligible
                    ? AppChipTone.success
                    : AppChipTone.warning,
              ),
          ],
        ),
        // Hero-only pay-emphasis block: same `payAmount` value the plain
        // card shows inline, just given real visual weight -- large bold
        // numerals plus a muted "estimated" caption, separated from the
        // content above by a thin divider (the same weight-through-scale
        // treatment `TodayMissionCard` gives its own headline stat).
        if (isHero) ...[
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${shift.payAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Text(
                    'estimated',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    if (!isHero) {
      return AppCard(
        onTap: onTap,
        semanticLabel: 'Open ${shift.roleTitle} at ${shift.siteName}',
        child: content,
      );
    }

    // AppCard now supports a boxShadow override (see AppCard.boxShadow),
    // but it bakes in AppRadius.largeBorder for both its Material shape and
    // that shadow's own rounded rect -- this hero card wants the rounder
    // AppRadius.extraLargeBorder every other Shift/Home hero surface uses,
    // which AppCard has no knob for. So this stays a local Container +
    // AppShadows.hero composition, wrapping the same tap-ripple +
    // rounded-corner behaviour, rather than migrating to AppCard and
    // silently shrinking the hero card's corners.
    return Semantics(
      container: true,
      button: true,
      label: 'Open ${shift.roleTitle} at ${shift.siteName}',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.extraLargeBorder,
            boxShadow: AppShadows.hero,
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.extraLargeBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky footer CTA for the current best-match shift -- the one persistent
/// way to accept a shift, alongside the existing tap-a-card-then-accept
/// path. Opens the same bottom sheet a card tap would rather than
/// duplicating `_ShiftDetailsState._accept`'s loading/error handling here.
class _AcceptShiftFooter extends StatelessWidget {
  const _AcceptShiftFooter({required this.shift, required this.onTap});

  final Shift shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppStickyFooter(
      child: AppButton(
        label: 'Accept shift · ₹${shift.payAmount.toStringAsFixed(0)}',
        onPressed: onTap,
        semanticLabel:
            'Accept ${shift.roleTitle} shift for '
            '₹${shift.payAmount.toStringAsFixed(0)}',
      ),
    );
  }
}

String _statusLabel(ShiftApplicationStatus status) => switch (status) {
  ShiftApplicationStatus.accepted => 'Accepted',
  ShiftApplicationStatus.confirmed => 'Confirmed',
  ShiftApplicationStatus.checkedIn => 'Checked in',
  ShiftApplicationStatus.completed => 'Completed',
  ShiftApplicationStatus.noShow => 'No show',
  ShiftApplicationStatus.cancelled => 'Cancelled',
  ShiftApplicationStatus.disputed => 'Disputed',
};

AppChipTone _statusTone(ShiftApplicationStatus status) => switch (status) {
  ShiftApplicationStatus.accepted ||
  ShiftApplicationStatus.confirmed => AppChipTone.info,
  ShiftApplicationStatus.checkedIn => AppChipTone.warning,
  ShiftApplicationStatus.completed => AppChipTone.success,
  ShiftApplicationStatus.noShow ||
  ShiftApplicationStatus.cancelled ||
  ShiftApplicationStatus.disputed => AppChipTone.error,
};

class _ShiftDetails extends StatefulWidget {
  const _ShiftDetails({
    required this.shift,
    required this.match,
    required this.application,
    required this.isLiveData,
    required this.onOpenSkillGap,
    required this.onAccept,
  });

  final Shift shift;
  final ShiftMatch match;
  final ShiftApplication? application;
  final bool isLiveData;
  final VoidCallback onOpenSkillGap;
  final Future<AppFailure?> Function() onAccept;

  @override
  State<_ShiftDetails> createState() => _ShiftDetailsState();
}

class _ShiftDetailsState extends State<_ShiftDetails> {
  bool _accepting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final dateFormat = DateFormat('EEE, d MMM • h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${shift.siteName} • ${shift.city}'),
        const SizedBox(height: AppSpacing.xxs),
        Text(shift.siteAddress),
        const SizedBox(height: AppSpacing.md),
        Text('Shift', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(dateFormat.format(shift.startsAt)),
        Text('Ends ${dateFormat.format(shift.endsAt)}'),
        const SizedBox(height: AppSpacing.md),
        Text('Pay', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '₹${shift.payAmount.toStringAsFixed(0)} ${shift.payCurrency} (estimated)',
        ),
        if (shift.description != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'About this shift',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(shift.description!),
        ],
        if (shift.supervisorName != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Supervisor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(shift.supervisorName!),
        ],
        if (shift.cancellationPolicy != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Cancellation policy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(shift.cancellationPolicy!),
        ],
        const SizedBox(height: AppSpacing.md),
        const AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Text(
            'Flora is facilitating this shift. Final attendance and payout '
            'approval follows the company’s shift policy.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.application != null)
          AppCard(
            child: Text(
              'You have already ${_statusLabel(widget.application!.status).toLowerCase()} this shift. Open "My shifts" to check in or out.',
            ),
          )
        else if (!widget.match.isEligible) ...[
          Text(
            'Before accepting this shift',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Complete: ${widget.match.missingCompetencyIds.map(_displayName).join(', ')}',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenSkillGap();
            },
            child: const Text('Complete required skill'),
          ),
        ] else ...[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          FilledButton(
            onPressed: _accepting ? null : _accept,
            child: Text(_accepting ? 'Accepting…' : 'Accept shift'),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        const AppBottomSheetCloseButton(),
      ],
    );
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final failure = await widget.onAccept();
    if (!mounted) return;
    if (failure == null) {
      showAppSnackBar(
        context: context,
        message: 'Shift accepted.',
        tone: AppMessageTone.success,
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _accepting = false;
        _error = failure.message;
      });
    }
  }

  String _displayName(String competencyId) => competencyId
      .split(RegExp('[-_]'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _ShiftLoadingView extends StatelessWidget {
  const _ShiftLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppSkeleton(height: 56),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 140),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 140),
        ],
      ),
    );
  }
}
