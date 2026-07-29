import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

class WorkplaceOverviewHandoffScreen extends StatelessWidget {
  const WorkplaceOverviewHandoffScreen({
    required this.onReturnToPractice,
    super.key,
  });

  final VoidCallback onReturnToPractice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workplace Overview')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift started',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Your attempt is safely in progress and the Document Desk is the first available workstation.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'The operational floor will be added only from the approved Screen 03 specification. No workstation layout or interaction has been invented here.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Return to Practice',
                      onPressed: onReturnToPractice,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
