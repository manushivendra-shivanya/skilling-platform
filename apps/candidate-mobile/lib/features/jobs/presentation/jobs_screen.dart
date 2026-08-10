import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/jobs_repository.dart';
import 'job_filters.dart';
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
    final notifier = ref.read(jobsControllerProvider.notifier);
    final items = state.visibleJobs();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.isLiveData
                    ? 'Openings from verified employers'
                    : 'Demo opportunities • No live employer connection',
                style: const TextStyle(color: AppColors.inkMuted),
              ),
            ),
            _SavedJobsButton(state: state),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Search role, company, or city',
          leadingIcon: Icons.search,
          onChanged: notifier.search,
          trailing: _FilterTrigger(state: state),
        ),
        if (!state.filters.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ActiveFilterPills(state: state, notifier: notifier),
        ],
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<JobsTab>(
          segments: const [
            ButtonSegment(
              value: JobsTab.forYou,
              label: Text('For you'),
              icon: Icon(Icons.auto_awesome_outlined, size: 16),
            ),
            ButtonSegment(value: JobsTab.all, label: Text('All jobs')),
          ],
          selected: {state.tab},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => notifier.setTab(selection.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          state.tab == JobsTab.forYou
              ? 'Ranked for you • ${items.length} job${items.length == 1 ? '' : 's'}'
              : '${items.length} job${items.length == 1 ? '' : 's'}, newest first',
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          SizedBox(
            height: 260,
            child: AppEmptyState(
              title: 'No matching jobs',
              message: state.filters.isEmpty
                  ? 'Try another title, location, or city.'
                  : 'Try another search, or clear a filter to see more.',
            ),
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            _StaggeredEntrance(
              index: i,
              child: _JobCard(
                item: items[i],
                showMatch: state.tab == JobsTab.forYou,
                isSaved: state.savedJobIds.contains(items[i].job.id),
                isApplied: state.appliedJobIds.contains(items[i].job.id),
                isLiveData: state.isLiveData,
                onTap: () => _showJobDetails(context, ref, items[i].job),
                onSaveToggle: () => notifier.toggleSaved(items[i].job.id),
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
        isLiveData: state.isLiveData,
        onApply: () => ref.read(jobsControllerProvider.notifier).apply(job.id),
      ),
    );
  }
}

class _FilterTrigger extends ConsumerWidget {
  const _FilterTrigger({required this.state});

  final JobsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = state.filters.activeCount;
    return IconButton(
      tooltip: 'Filters',
      onPressed: () => _showFilterSheet(context, ref, state),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.tune),
      ),
    );
  }
}

Future<void> _showFilterSheet(
  BuildContext context,
  WidgetRef ref,
  JobsState state,
) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Filters',
    child: _FilterSheetContent(
      jobs: state.jobs,
      availableLocations: state.availableLocations,
      availableCompanies: state.availableCompanies,
      initial: state.filters,
      onApply: (filters) =>
          ref.read(jobsControllerProvider.notifier).applyFilters(filters),
    ),
  );
}

class _ActiveFilterPills extends StatelessWidget {
  const _ActiveFilterPills({required this.state, required this.notifier});

  final JobsState state;
  final JobsController notifier;

  @override
  Widget build(BuildContext context) {
    final filters = state.filters;
    final pills = <(String, VoidCallback)>[
      for (final location in filters.locations)
        (
          location,
          () => notifier.applyFilters(
            filters.copyWith(
              locations: filters.locations.toSet()..remove(location),
            ),
          ),
        ),
      for (final role in filters.roles)
        (
          _roleLabel(role),
          () => notifier.applyFilters(
            filters.copyWith(roles: filters.roles.toSet()..remove(role)),
          ),
        ),
      for (final company in filters.companies)
        (
          company,
          () => notifier.applyFilters(
            filters.copyWith(
              companies: filters.companies.toSet()..remove(company),
            ),
          ),
        ),
      if (filters.datePosted != DatePostedFilter.any)
        (
          filters.datePosted == DatePostedFilter.pastWeek
              ? 'Past week'
              : 'Past month',
          () => notifier.applyFilters(
            filters.copyWith(datePosted: DatePostedFilter.any),
          ),
        ),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (label, onDeleted) in pills)
          InputChip(
            label: Text(label),
            onDeleted: onDeleted,
            backgroundColor: AppColors.brandSoft,
            labelStyle: const TextStyle(color: AppColors.brand),
            deleteIconColor: AppColors.brand,
            side: BorderSide.none,
          ),
        TextButton(
          onPressed: notifier.clearFilters,
          child: const Text('Clear all'),
        ),
      ],
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'warehouse' => 'Warehouse',
  'dispatch' => 'Dispatch',
  'inventory' => 'Inventory',
  'supervisor' => 'Supervisor',
  _ => role,
};

class _FilterSheetContent extends StatefulWidget {
  const _FilterSheetContent({
    required this.jobs,
    required this.availableLocations,
    required this.availableCompanies,
    required this.initial,
    required this.onApply,
  });

  final List<JobOpportunity> jobs;
  final List<String> availableLocations;
  final List<String> availableCompanies;
  final JobFilters initial;
  final ValueChanged<JobFilters> onApply;

  @override
  State<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends State<_FilterSheetContent> {
  late JobFilters _draft = widget.initial;

  int get _previewCount {
    final now = DateTime.now();
    return widget.jobs.where((job) => _draft.matches(job, now: now)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterSection(
          title: 'Location',
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final location in widget.availableLocations)
                FilterChip(
                  label: Text(location),
                  selected: _draft.locations.contains(location),
                  onSelected: (selected) => setState(() {
                    final next = _draft.locations.toSet();
                    selected ? next.add(location) : next.remove(location);
                    _draft = _draft.copyWith(locations: next);
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _FilterSection(
          title: 'Role type',
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final role in const [
                'warehouse',
                'dispatch',
                'inventory',
                'supervisor',
              ])
                FilterChip(
                  label: Text(_roleLabel(role)),
                  selected: _draft.roles.contains(role),
                  onSelected: (selected) => setState(() {
                    final next = _draft.roles.toSet();
                    selected ? next.add(role) : next.remove(role);
                    _draft = _draft.copyWith(roles: next);
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _FilterSection(
          title: 'Date posted',
          child: Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final option in DatePostedFilter.values)
                ChoiceChip(
                  label: Text(switch (option) {
                    DatePostedFilter.any => 'Any time',
                    DatePostedFilter.pastWeek => 'Past week',
                    DatePostedFilter.pastMonth => 'Past month',
                  }),
                  selected: _draft.datePosted == option,
                  onSelected: (_) => setState(
                    () => _draft = _draft.copyWith(datePosted: option),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _FilterSection(
          title: 'Company',
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final company in widget.availableCompanies)
                FilterChip(
                  label: Text(company),
                  selected: _draft.companies.contains(company),
                  onSelected: (selected) => setState(() {
                    final next = _draft.companies.toSet();
                    selected ? next.add(company) : next.remove(company);
                    _draft = _draft.copyWith(companies: next);
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _draft = JobFilters.empty),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_draft);
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Show $_previewCount job${_previewCount == 1 ? '' : 's'}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _SavedJobsButton extends StatelessWidget {
  const _SavedJobsButton({required this.state});

  final JobsState state;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Saved jobs',
      onPressed: () => _showSavedJobsSheet(context, state),
      icon: Badge(
        isLabelVisible: state.savedJobIds.isNotEmpty,
        label: Text('${state.savedJobIds.length}'),
        child: Icon(
          state.savedJobIds.isEmpty ? Icons.bookmark_border : Icons.bookmark,
        ),
      ),
    );
  }
}

Future<void> _showSavedJobsSheet(BuildContext context, JobsState state) {
  final savedJobs = state.jobs
      .where((job) => state.savedJobIds.contains(job.id))
      .toList();
  return showAppBottomSheet<void>(
    context: context,
    title: 'Saved jobs',
    child: savedJobs.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: AppEmptyState(
              title: 'No saved jobs yet',
              message: 'Tap the bookmark on any listing to keep it here.',
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final job in savedJobs) ...[
                AppCard(
                  onTap: () {
                    Navigator.of(context).pop();
                    showAppBottomSheet<void>(
                      context: context,
                      title: job.title,
                      child: _JobDetails(
                        job: job,
                        alreadyApplied: state.appliedJobIds.contains(job.id),
                        isLiveData: state.isLiveData,
                        onApply: () => Future.value(null),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text('${job.employer} • ${job.location}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
  );
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.item,
    required this.showMatch,
    required this.isSaved,
    required this.isApplied,
    required this.isLiveData,
    required this.onTap,
    required this.onSaveToggle,
  });

  final JobListItem item;
  final bool showMatch;
  final bool isSaved;
  final bool isApplied;
  final bool isLiveData;
  final VoidCallback onTap;
  final VoidCallback onSaveToggle;

  @override
  Widget build(BuildContext context) {
    final job = item.job;
    final isFlora = job.source == 'flora';
    final sourceName = jobSourceDisplayName(job.source);

    return AppCard(
      onTap: onTap,
      semanticLabel: 'Open ${job.title} at ${job.employer}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceAvatar(employer: job.employer, isFlora: isFlora),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (showMatch) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          _MatchBadge(score: item.matchScore),
                        ],
                      ],
                    ),
                    Text(
                      '${job.employer} • ${job.location}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isSaved ? 'Remove from saved' : 'Save job',
                onPressed: onSaveToggle,
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? AppColors.accent : AppColors.inkMuted,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            job.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isApplied)
                AppStatusChip(
                  label: isLiveData
                      ? 'Application submitted'
                      : 'Demo application saved',
                  tone: AppChipTone.success,
                )
              else if (isFlora)
                const AppStatusChip(
                  label: 'Flora Verified',
                  tone: AppChipTone.success,
                )
              else if (sourceName != null)
                AppStatusChip(label: 'via $sourceName', tone: AppChipTone.info),
              if (job.isSupervisorRole)
                const AppStatusChip(
                  label: 'Supervisor',
                  tone: AppChipTone.warning,
                ),
              Text(
                jobPostedLabel(job.publishedAt),
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.employer, required this.isFlora});

  final String employer;
  final bool isFlora;

  @override
  Widget build(BuildContext context) {
    final initials = employer
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFlora ? AppColors.brandSoft : AppColors.infoSoft,
        borderRadius: AppRadius.mediumBorder,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: isFlora ? AppColors.brand : AppColors.info,
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final isTop = score >= 85;
    return Semantics(
      label: '$score percent match',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isTop ? AppColors.brandSoft : AppColors.accentSoft,
          borderRadius: AppRadius.smallBorder,
        ),
        child: Text(
          '$score% match',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isTop ? AppColors.brand : AppColors.accent,
          ),
        ),
      ),
    );
  }
}

/// A one-shot fade + rise applied when a job card first mounts (the
/// loading-skeleton-to-real-list transition), not replayed on ordinary
/// filter/search/tab changes -- Flutter reuses this State across rebuilds
/// at the same list position, so `didChangeDependencies` only fires once
/// per genuinely new card. Respects reduced-motion by jumping straight to
/// the settled state instead of animating.
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(_fade);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: widget.index.clamp(0, 8) * 45), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _JobDetails extends StatefulWidget {
  const _JobDetails({
    required this.job,
    required this.alreadyApplied,
    required this.isLiveData,
    required this.onApply,
  });

  final JobOpportunity job;
  final bool alreadyApplied;
  final bool isLiveData;
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
    final sourceName = jobSourceDisplayName(widget.job.source);
    final header = <Widget>[
      Text('${widget.job.employer} • ${widget.job.location}'),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        'Posted ${jobPostedLabel(widget.job.publishedAt).toLowerCase()}',
        style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
      ),
      if (sourceName != null) ...[
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'via $sourceName',
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      Text(
        widget.isLiveData ? 'About this role' : 'Why this may match',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(widget.job.description),
      const SizedBox(height: AppSpacing.md),
    ];

    final applyUrl = widget.job.applyUrl;
    if (applyUrl != null) {
      // Aggregator-sourced listing -- there is no real Flora employer
      // behind it to receive an internal application, so the candidate is
      // sent to the real listing instead of the usual share-and-submit
      // flow below.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...header,
          Text(
            'This listing is sourced from $sourceName. Flora cannot submit '
            'an application on your behalf for it -- continue on the '
            'original listing to apply.',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => _openExternalListing(context, applyUrl),
            child: Text('View & apply on $sourceName'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppBottomSheetCloseButton(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...header,
        if (!widget.isLiveData)
          const Text(
            'Eligibility, salary, shifts, and employer verification are not available in this mock feed.',
          ),
        if (!widget.isLiveData) const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _sharingConfirmed,
          onChanged: widget.alreadyApplied
              ? null
              : (value) => setState(() => _sharingConfirmed = value ?? false),
          title: Text(
            widget.isLiveData
                ? 'Share your profile for this application'
                : 'Share this demo profile for this application',
          ),
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
                ? (widget.isLiveData
                      ? 'Application already submitted'
                      : 'Demo application already saved')
                : _saving
                ? (widget.isLiveData ? 'Submitting…' : 'Saving…')
                : (widget.isLiveData
                      ? 'Submit application'
                      : 'Save demo application'),
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

  Future<void> _openExternalListing(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppSnackBar(
        context: context,
        message: 'This listing could not be opened.',
        tone: AppMessageTone.error,
      );
    }
  }
}

class _JobsLoadingView extends StatelessWidget {
  const _JobsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              'Finding jobs for you…',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSkeletonGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSkeleton(height: 56),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(height: 40),
              SizedBox(height: AppSpacing.lg),
              _JobCardSkeleton(),
              SizedBox(height: AppSpacing.md),
              _JobCardSkeleton(),
              SizedBox(height: AppSpacing.md),
              _JobCardSkeleton(),
              SizedBox(height: AppSpacing.md),
              _JobCardSkeleton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _JobCardSkeleton extends StatelessWidget {
  const _JobCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(
            height: 40,
            width: 40,
            borderRadius: AppRadius.mediumBorder,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(height: 15, width: 180),
                SizedBox(height: AppSpacing.xs),
                AppSkeleton(height: 12, width: 120),
                SizedBox(height: AppSpacing.sm),
                AppSkeleton(height: 12),
                SizedBox(height: AppSpacing.xxs),
                AppSkeleton(height: 12, width: 220),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
