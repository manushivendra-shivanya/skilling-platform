import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/shift_payout.dart';
import 'shift_payout_controller.dart';

class ShiftPayoutScreen extends ConsumerWidget {
  const ShiftPayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftPayoutControllerProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.payoutsTitle)),
      body: SafeArea(
        child: state.when(
          loading: () => Center(
            child: AppLoadingProgressBar(label: l10n.payoutsLoadingLabel),
          ),
          error: (error, stackTrace) => AppErrorState(
            title: l10n.payoutsLoadErrorTitle,
            message: error is AppFailure
                ? error.localizedMessage(l10n)
                : l10n.payoutsLoadErrorFallback,
            onAction: () =>
                ref.read(shiftPayoutControllerProvider.notifier).retry(),
          ),
          data: (payouts) => payouts.isEmpty
              ? AppEmptyState(
                  title: l10n.payoutsEmptyTitle,
                  message: l10n.payoutsEmptyMessage,
                )
              : _PayoutList(payouts: payouts),
        ),
      ),
    );
  }
}

class _PayoutList extends StatelessWidget {
  const _PayoutList({required this.payouts});

  final List<ShiftPayout> payouts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('d MMM yyyy');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: [
        Text(
          l10n.payoutsTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.payoutsCount(payouts.length),
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Text(l10n.payoutsDisclaimer),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final payout in payouts) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${payout.total.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppStatusChip(
                      label: _statusLabel(payout.status, l10n),
                      tone: _statusTone(payout.status),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.payoutsBasePayLabel(payout.basePay.toStringAsFixed(0)),
                ),
                if (payout.bonus > 0)
                  Text(l10n.payoutsBonusLabel(payout.bonus.toStringAsFixed(0))),
                if (payout.deductions > 0)
                  Text(
                    l10n.payoutsDeductionsLabel(
                      payout.deductions.toStringAsFixed(0),
                    ),
                  ),
                if (payout.expectedPayoutDate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.payoutsExpectedLabel(
                      dateFormat.format(payout.expectedPayoutDate!),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  String _statusLabel(ShiftPayoutStatus status, AppLocalizations l10n) =>
      switch (status) {
        ShiftPayoutStatus.pendingApproval => l10n.payoutStatusPendingApproval,
        ShiftPayoutStatus.approved => l10n.payoutStatusApproved,
        ShiftPayoutStatus.processing => l10n.payoutStatusProcessing,
        ShiftPayoutStatus.paid => l10n.payoutStatusPaid,
        ShiftPayoutStatus.failed => l10n.payoutStatusFailed,
        ShiftPayoutStatus.disputed => l10n.payoutStatusDisputed,
      };

  AppChipTone _statusTone(ShiftPayoutStatus status) => switch (status) {
    ShiftPayoutStatus.pendingApproval => AppChipTone.neutral,
    ShiftPayoutStatus.approved ||
    ShiftPayoutStatus.processing => AppChipTone.info,
    ShiftPayoutStatus.paid => AppChipTone.success,
    ShiftPayoutStatus.failed || ShiftPayoutStatus.disputed => AppChipTone.error,
  };
}
