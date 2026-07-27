import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';

class MainDestinationScreen extends StatefulWidget {
  const MainDestinationScreen({
    required this.title,
    required this.phaseLabel,
    required this.description,
    required this.plannedItems,
    super.key,
  });

  final String title;
  final String phaseLabel;
  final String description;
  final List<String> plannedItems;

  @override
  State<MainDestinationScreen> createState() => _MainDestinationScreenState();
}

class _MainDestinationScreenState extends State<MainDestinationScreen> {
  bool _showPlannedItems = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        key: PageStorageKey<String>('${widget.title}-destination-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.section,
        ),
        children: [
          AppStatusChip(label: widget.phaseLabel, tone: AppChipTone.info),
          const SizedBox(height: AppSpacing.md),
          Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.construction_outlined,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Foundation route is ready',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'This destination is part of the production navigation shell. Its product content will be added in the phase shown above.',
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showPlannedItems = !_showPlannedItems),
                  icon: Icon(
                    _showPlannedItems ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text(
                    _showPlannedItems
                        ? 'Hide planned features'
                        : 'Show planned features',
                  ),
                ),
                if (_showPlannedItems) ...[
                  const Divider(),
                  const SizedBox(height: AppSpacing.xs),
                  for (final item in widget.plannedItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: AppColors.outline,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
