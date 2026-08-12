import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../domain/shift_payout.dart';
import 'shift_payout_controller.dart';

class ShiftPayoutScreen extends ConsumerWidget {
  const ShiftPayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftPayoutControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your payouts…'),
          ),
          error: (error, stackTrace) => AppErrorState(
            title: 'Payouts could not be loaded',
            message: error is AppFailure
                ? error.message
                : 'Payouts are temporarily unavailable.',
            onAction: () =>
                ref.read(shiftPayoutControllerProvider.notifier).retry(),
          ),
          data: (payouts) => payouts.isEmpty
              ? const AppEmptyState(
                  title: 'No payouts yet',
                  message: 'Payouts appear here once you check out of a shift.',
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
    final dateFormat = DateFormat('d MMM yyyy');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: [
        Text('Payouts', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${payouts.length} payout${payouts.length == 1 ? '' : 's'}',
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Text(
            'This is a status ledger, not a wallet -- Flora does not move '
            'money directly yet. Approved payouts are disbursed by the '
            'company according to its own payout policy.',
          ),
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
                      label: _statusLabel(payout.status),
                      tone: _statusTone(payout.status),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Base pay: ₹${payout.basePay.toStringAsFixed(0)}'),
                if (payout.bonus > 0)
                  Text('Bonus: ₹${payout.bonus.toStringAsFixed(0)}'),
                if (payout.deductions > 0)
                  Text('Deductions: ₹${payout.deductions.toStringAsFixed(0)}'),
                if (payout.expectedPayoutDate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Expected: ${dateFormat.format(payout.expectedPayoutDate!)}',
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

  String _statusLabel(ShiftPayoutStatus status) => switch (status) {
    ShiftPayoutStatus.pendingApproval => 'Pending approval',
    ShiftPayoutStatus.approved => 'Approved',
    ShiftPayoutStatus.processing => 'Processing',
    ShiftPayoutStatus.paid => 'Paid',
    ShiftPayoutStatus.failed => 'Failed',
    ShiftPayoutStatus.disputed => 'Disputed',
  };

  AppChipTone _statusTone(ShiftPayoutStatus status) => switch (status) {
    ShiftPayoutStatus.pendingApproval => AppChipTone.neutral,
    ShiftPayoutStatus.approved ||
    ShiftPayoutStatus.processing => AppChipTone.info,
    ShiftPayoutStatus.paid => AppChipTone.success,
    ShiftPayoutStatus.failed || ShiftPayoutStatus.disputed => AppChipTone.error,
  };
}
