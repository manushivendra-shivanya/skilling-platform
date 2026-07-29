import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/jobs_repository.dart';
import 'jobs_controller.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobsControllerProvider);
    return state.when(
      loading: () => const _JobsLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: 'Jobs could not be loaded',
        message: error is AppFailure
            ? error.message
            : 'The local demo job feed is unavailable.',
        onAction: () => ref.read(jobsControllerProvider.notifier).retry(),
      ),
      data: (value) => _JobsContent(state: value),
    );
  }
}

class _JobsContent extends ConsumerWidget {
  const _JobsContent({required this.state});

  final JobsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleJobs = state.visibleJobs;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        const Text(
          'Demo opportunities • No live employer connection',
          style: TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Search jobs or locations',
          leadingIcon: Icons.search,
          onChanged: ref.read(jobsControllerProvider.notifier).search,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text('Supervisor roles'),
            selected: state.supervisorOnly,
            onSelected: (_) => ref
                .read(jobsControllerProvider.notifier)
                .toggleSupervisorOnly(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (visibleJobs.isEmpty)
          const SizedBox(
            height: 260,
            child: AppEmptyState(
              title: 'No matching demo jobs',
              message: 'Try another title, location, or remove the filter.',
            ),
          )
        else
          for (final job in visibleJobs) ...[
            AppCard(
              onTap: () => _showJobDetails(context, ref, job),
              semanticLabel: 'Open ${job.title} at ${job.employer}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('${job.employer} • ${job.location}'),
                  const SizedBox(height: AppSpacing.sm),
                  AppStatusChip(
                    label: state.appliedJobIds.contains(job.id)
                        ? 'Demo application saved'
                        : 'View match explanation',
                    tone: state.appliedJobIds.contains(job.id)
                        ? AppChipTone.success
                        : AppChipTone.info,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  Future<void> _showJobDetails(
    BuildContext context,
    WidgetRef ref,
    JobOpportunity job,
  ) {
    return showAppBottomSheet<void>(
      context: context,
      title: job.title,
      child: _JobDetails(
        job: job,
        alreadyApplied: state.appliedJobIds.contains(job.id),
        onApply: () => ref.read(jobsControllerProvider.notifier).apply(job.id),
      ),
    );
  }
}

class _JobDetails extends StatefulWidget {
  const _JobDetails({
    required this.job,
    required this.alreadyApplied,
    required this.onApply,
  });

  final JobOpportunity job;
  final bool alreadyApplied;
  final Future<AppFailure?> Function() onApply;

  @override
  State<_JobDetails> createState() => _JobDetailsState();
}

class _JobDetailsState extends State<_JobDetails> {
  bool _sharingConfirmed = false;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${widget.job.employer} • ${widget.job.location}'),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Why this may match',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(widget.job.matchReason),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Eligibility, salary, shifts, and employer verification are not available in this mock feed.',
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _sharingConfirmed,
          onChanged: widget.alreadyApplied
              ? null
              : (value) => setState(() => _sharingConfirmed = value ?? false),
          title: const Text('Share this demo profile for this application'),
          subtitle: const Text('Required before applying.'),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        FilledButton(
          onPressed: widget.alreadyApplied || !_sharingConfirmed || _saving
              ? null
              : _apply,
          child: Text(
            widget.alreadyApplied
                ? 'Demo application already saved'
                : _saving
                ? 'Saving…'
                : 'Save demo application',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppBottomSheetCloseButton(),
      ],
    );
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    final failure = await widget.onApply();
    if (!mounted) return;
    if (failure == null) {
      showAppSnackBar(
        context: context,
        message: 'Your application was saved.',
        tone: AppMessageTone.success,
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
    }
  }
}

class _JobsLoadingView extends StatelessWidget {
  const _JobsLoadingView();

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
