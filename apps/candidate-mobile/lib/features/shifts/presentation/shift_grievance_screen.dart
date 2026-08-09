import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/shift_grievance.dart';
import 'shift_grievance_controller.dart';

class ShiftGrievanceScreen extends ConsumerWidget {
  const ShiftGrievanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftGrievanceControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorState(
            title: 'Support tickets could not be loaded',
            message: error is AppFailure
                ? error.message
                : 'Support tickets are temporarily unavailable.',
            onAction: () => ref.invalidate(shiftGrievanceControllerProvider),
          ),
          data: (grievances) => _GrievanceContent(grievances: grievances),
        ),
      ),
    );
  }
}

class _GrievanceContent extends ConsumerStatefulWidget {
  const _GrievanceContent({required this.grievances});

  final List<ShiftGrievance> grievances;

  @override
  ConsumerState<_GrievanceContent> createState() => _GrievanceContentState();
}

class _GrievanceContentState extends ConsumerState<_GrievanceContent> {
  ShiftGrievanceCategory _category = ShiftGrievanceCategory.other;
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

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
        Text('Raise a ticket', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<ShiftGrievanceCategory>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final category in ShiftGrievanceCategory.values)
              DropdownMenuItem(
                value: category,
                child: Text(category.displayLabel),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'What happened?',
          controller: _descriptionController,
          maxLines: 4,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
          ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: _submitting ? 'Submitting…' : 'Submit ticket',
          isLoading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Your tickets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (widget.grievances.isEmpty)
          const AppEmptyState(
            title: 'No tickets yet',
            message: 'Anything you raise about a shift shows up here.',
          )
        else
          for (final grievance in widget.grievances) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${grievance.ticketReference}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      AppStatusChip(
                        label: _statusLabel(grievance.status),
                        tone: _statusTone(grievance.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(grievance.category.displayLabel),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(grievance.description),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(dateFormat.format(grievance.createdAt)),
                  if (grievance.resolutionNotes != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('Resolution: ${grievance.resolutionNotes}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Describe what happened.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final failure = await ref
        .read(shiftGrievanceControllerProvider.notifier)
        .submit(
          category: _category,
          description: _descriptionController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (failure == null) {
      _descriptionController.clear();
      showAppSnackBar(
        context: context,
        message: 'Ticket submitted.',
        tone: AppMessageTone.success,
      );
    } else {
      setState(() => _error = failure.message);
    }
  }

  String _statusLabel(ShiftGrievanceStatus status) => switch (status) {
    ShiftGrievanceStatus.open => 'Open',
    ShiftGrievanceStatus.inReview => 'In review',
    ShiftGrievanceStatus.resolved => 'Resolved',
    ShiftGrievanceStatus.closed => 'Closed',
  };

  AppChipTone _statusTone(ShiftGrievanceStatus status) => switch (status) {
    ShiftGrievanceStatus.open => AppChipTone.warning,
    ShiftGrievanceStatus.inReview => AppChipTone.info,
    ShiftGrievanceStatus.resolved ||
    ShiftGrievanceStatus.closed => AppChipTone.success,
  };
}
