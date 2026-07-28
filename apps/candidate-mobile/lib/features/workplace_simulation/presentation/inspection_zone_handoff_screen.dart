import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';

class InspectionZoneHandoffScreen extends ConsumerWidget {
  const InspectionZoneHandoffScreen({
    required this.missionId,
    required this.onBack,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulation = ref.watch(workplaceSimulationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection Zone')),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Inspection Zone unavailable',
            message: 'Return to the Workplace Overview and retry.',
            actionLabel: 'Back to Workplace',
            onAction: onBack,
          ),
          data: (state) {
            final overview = ref
                .read(workplaceSimulationControllerProvider.notifier)
                .workplaceOverview;
            final station = overview.workstations.firstWhere(
              (item) => item.workstationId == 'inspection-zone',
            );
            if (state.mission.id != missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Inspection Zone is locked',
                message: station.supportingText,
                actionLabel: 'Back to Workplace',
                onAction: onBack,
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inspection Zone unlocked',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${state.mission.title} · ${state.workplace.name}',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Inspection workflow coming next.'),
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Back to Workplace',
                          onPressed: onBack,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
