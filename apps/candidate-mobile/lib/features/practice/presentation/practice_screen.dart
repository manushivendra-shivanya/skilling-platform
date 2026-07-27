import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _demoOpen = false;
  String? _selectedDecision;

  @override
  Widget build(BuildContext context) {
    if (_demoOpen) {
      return _InventoryDemo(
        selectedDecision: _selectedDecision,
        onSelect: (value) => setState(() => _selectedDecision = value),
        onClose: () => setState(() {
          _demoOpen = false;
          _selectedDecision = null;
        }),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Practice demonstrations are not scored assessments and create no employer evidence.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Recommended practice',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.brandSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Inventory discrepancy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Compare a system quantity with a physical count and choose a safe next action.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Start demonstration',
                onPressed: () => setState(() => _demoOpen = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Catalogue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.local_shipping_outlined),
            title: Text('Dispatch prioritisation'),
            subtitle: Text('Preview planned • demonstration only'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Voice workplace practice'),
            subtitle: const Text('Planned • microphone is not active'),
            onTap: () => showAppSnackBar(
              context: context,
              message:
                  'Voice practice is not active. No microphone permission was requested.',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Attempt history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const SizedBox(
          height: 180,
          child: AppEmptyState(
            title: 'No scored attempts',
            message:
                'Demonstrations do not appear as assessed evidence or affect reliability.',
          ),
        ),
      ],
    );
  }
}

class _InventoryDemo extends StatelessWidget {
  const _InventoryDemo({
    required this.selectedDecision,
    required this.onSelect,
    required this.onClose,
  });

  final String? selectedDecision;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(
          'Inventory discrepancy demo',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text('System: 24 units • Physical count: 21 units'),
        const SizedBox(height: AppSpacing.lg),
        for (final option in const [
          'Change the system quantity immediately',
          'Recount, preserve records, and escalate the mismatch',
          'Ignore the difference until the shift ends',
        ]) ...[
          AppCard(
            onTap: () => onSelect(option),
            semanticLabel:
                '$option. ${selectedDecision == option ? 'Selected' : 'Not selected'}',
            backgroundColor: selectedDecision == option
                ? AppColors.brandSoft
                : AppColors.surface,
            child: Row(
              children: [
                Expanded(child: Text(option)),
                Icon(
                  selectedDecision == option
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selectedDecision == option
                      ? AppColors.brand
                      : AppColors.outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (selectedDecision != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            backgroundColor: AppColors.infoSoft,
            child: Text(
              selectedDecision ==
                      'Recount, preserve records, and escalate the mismatch'
                  ? 'Good practice: verify the count, keep an audit trail, and escalate according to SOP.'
                  : 'Try again: safe operations preserve records and escalate unexplained discrepancies.',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const Text(
          'If the app or network fails during a future assessment, the technical failure must not reduce candidate reliability.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Return to practice',
          variant: AppButtonVariant.secondary,
          onPressed: onClose,
        ),
      ],
    );
  }
}
