import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_elevation.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_accent_pill.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_initials_avatar.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/reduced_motion.dart';
import '../../../l10n/generated/app_localizations.dart';
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
            ? error.localizedMessage(AppLocalizations.of(context))
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
        AppCard(
          elevation: AppElevation.medium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                onSelectionChanged: (selection) =>
                    notifier.setTab(selection.first),
              ),
            ],
          ),
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
                // The For-you tab is already sorted by matchScore
                // (descending, see JobsController.visibleJobs) -- so the
                // first card genuinely is the best match, and this ribbon
                // just states that existing fact. A ribbon on a list of
                // one wouldn't mean anything ("top" of one), so it's
                // withheld there.
                isTopMatch:
                    i == 0 && state.tab == JobsTab.forYou && items.length > 1,
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
    return showJobDetailsSheet(
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

/// Job-detail-specific bottom sheet: a [DraggableScrollableSheet] that
/// opens large (85% of the screen) by default and can be dragged down to
/// 50% or up to 95%, rather than [showAppBottomSheet]'s shrink-to-content
/// sizing. Deliberately its own function, not a change to
/// [showAppBottomSheet] itself -- that helper is shared by every other
/// bottom sheet in the app (Career Passport, Shifts, ...), and this is a
/// Jobs-detail-specific sizing choice, not something those screens asked
/// for.
Future<void> showJobDetailsSheet({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.smallBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      ),
    ),
  );
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

enum _FilterCategory { location, role, datePosted, company }

const _roleOptions = ['warehouse', 'dispatch', 'inventory', 'supervisor'];

String _datePostedLabel(DatePostedFilter option) => switch (option) {
  DatePostedFilter.any => 'Any time',
  DatePostedFilter.pastWeek => 'Past week',
  DatePostedFilter.pastMonth => 'Past month',
};

/// A drill-down filter sheet, not a single screen of every option at
/// once: a category list up front (Location / Role type / Date posted /
/// Company), each opening its own sub-page with a search field where the
/// option list can genuinely grow (Location, Company -- built from
/// whatever's actually in the live catalogue) and a plain tick-box list
/// where it can't (Role type's 4 fixed buckets, Date posted's 3 fixed
/// windows). Matches the category-drawer pattern real shopping/job apps
/// use once there's more than a handful of options to choose from -- a
/// flat wall of chips stops scaling the moment the catalogue has more
/// than a few cities or employers in it.
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
  _FilterCategory? _activeCategory;
  String _searchTerm = '';

  int get _previewCount {
    final now = DateTime.now();
    return widget.jobs.where((job) => _draft.matches(job, now: now)).length;
  }

  void _openCategory(_FilterCategory category) {
    setState(() {
      _activeCategory = category;
      _searchTerm = '';
    });
  }

  void _closeCategory() => setState(() => _activeCategory = null);

  @override
  Widget build(BuildContext context) {
    final active = _activeCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active == null) _buildCategoryList() else _buildSubPage(active),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _draft = JobFilters.empty),
                child: const Text('Reset all'),
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

  Widget _buildCategoryList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CategoryTile(
          label: 'Location',
          summary: _draft.locations.isEmpty
              ? 'Any'
              : _draft.locations.join(', '),
          onTap: () => _openCategory(_FilterCategory.location),
        ),
        _CategoryTile(
          label: 'Role type',
          summary: _draft.roles.isEmpty
              ? 'Any'
              : _draft.roles.map(_roleLabel).join(', '),
          onTap: () => _openCategory(_FilterCategory.role),
        ),
        _CategoryTile(
          label: 'Date posted',
          summary: _datePostedLabel(_draft.datePosted),
          onTap: () => _openCategory(_FilterCategory.datePosted),
        ),
        _CategoryTile(
          label: 'Company',
          summary: _draft.companies.isEmpty
              ? 'Any'
              : _draft.companies.join(', '),
          onTap: () => _openCategory(_FilterCategory.company),
        ),
      ],
    );
  }

  Widget _buildSubPage(_FilterCategory category) {
    final title = switch (category) {
      _FilterCategory.location => 'Location',
      _FilterCategory.role => 'Role type',
      _FilterCategory.datePosted => 'Date posted',
      _FilterCategory.company => 'Company',
    };
    final hasSearch =
        category == _FilterCategory.location ||
        category == _FilterCategory.company;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _closeCategory,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to filters',
            ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_hasSelection(category))
              TextButton(
                onPressed: () => setState(() => _draft = _clear(category)),
                child: const Text('Clear'),
              ),
          ],
        ),
        if (hasSearch) ...[
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            key: const Key('filterCategorySearchField'),
            label: 'Search $title'.toLowerCase(),
            leadingIcon: Icons.search,
            onChanged: (value) => setState(() => _searchTerm = value),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        SizedBox(height: 320, child: _buildOptionList(category)),
      ],
    );
  }

  Widget _buildOptionList(_FilterCategory category) {
    switch (category) {
      case _FilterCategory.location:
        return _checklist(
          options: _filterBySearch(widget.availableLocations),
          isSelected: _draft.locations.contains,
          onToggle: (value, selected) => setState(() {
            final next = _draft.locations.toSet();
            selected ? next.add(value) : next.remove(value);
            _draft = _draft.copyWith(locations: next);
          }),
          emptyMessage: 'No locations match "$_searchTerm".',
        );
      case _FilterCategory.company:
        return _checklist(
          options: _filterBySearch(widget.availableCompanies),
          isSelected: _draft.companies.contains,
          onToggle: (value, selected) => setState(() {
            final next = _draft.companies.toSet();
            selected ? next.add(value) : next.remove(value);
            _draft = _draft.copyWith(companies: next);
          }),
          emptyMessage: 'No companies match "$_searchTerm".',
        );
      case _FilterCategory.role:
        return _checklist(
          options: _roleOptions,
          labelFor: _roleLabel,
          isSelected: _draft.roles.contains,
          onToggle: (value, selected) => setState(() {
            final next = _draft.roles.toSet();
            selected ? next.add(value) : next.remove(value);
            _draft = _draft.copyWith(roles: next);
          }),
        );
      case _FilterCategory.datePosted:
        return RadioGroup<DatePostedFilter>(
          groupValue: _draft.datePosted,
          onChanged: (value) {
            if (value != null) {
              setState(() => _draft = _draft.copyWith(datePosted: value));
            }
          },
          child: ListView(
            children: [
              for (final option in DatePostedFilter.values)
                RadioListTile<DatePostedFilter>(
                  title: Text(_datePostedLabel(option)),
                  value: option,
                ),
            ],
          ),
        );
    }
  }

  Widget _checklist({
    required List<String> options,
    required bool Function(String) isSelected,
    required void Function(String value, bool selected) onToggle,
    String Function(String)? labelFor,
    String? emptyMessage,
  }) {
    if (options.isEmpty) {
      return Center(
        child: Text(
          emptyMessage ?? 'No options available.',
          style: const TextStyle(color: AppColors.inkMuted),
        ),
      );
    }
    return ListView(
      children: [
        for (final option in options)
          CheckboxListTile(
            title: Text(labelFor == null ? option : labelFor(option)),
            value: isSelected(option),
            onChanged: (selected) => onToggle(option, selected ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }

  List<String> _filterBySearch(List<String> options) {
    if (_searchTerm.trim().isEmpty) return options;
    final normalized = _searchTerm.trim().toLowerCase();
    return options
        .where((option) => option.toLowerCase().contains(normalized))
        .toList();
  }

  bool _hasSelection(_FilterCategory category) => switch (category) {
    _FilterCategory.location => _draft.locations.isNotEmpty,
    _FilterCategory.role => _draft.roles.isNotEmpty,
    _FilterCategory.company => _draft.companies.isNotEmpty,
    _FilterCategory.datePosted => _draft.datePosted != DatePostedFilter.any,
  };

  JobFilters _clear(_FilterCategory category) => switch (category) {
    _FilterCategory.location => _draft.copyWith(locations: const {}),
    _FilterCategory.role => _draft.copyWith(roles: const {}),
    _FilterCategory.company => _draft.copyWith(companies: const {}),
    _FilterCategory.datePosted => _draft.copyWith(
      datePosted: DatePostedFilter.any,
    ),
  };
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.summary,
    required this.onTap,
  });

  final String label;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.inkMuted),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
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
                    showJobDetailsSheet(
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
    required this.isTopMatch,
    required this.isSaved,
    required this.isApplied,
    required this.isLiveData,
    required this.onTap,
    required this.onSaveToggle,
  });

  final JobListItem item;
  final bool showMatch;

  /// Whether this card is the #1 result on the (already match-sorted)
  /// For-you tab -- see the "Top match for you" ribbon this draws when
  /// true.
  final bool isTopMatch;
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

    final card = AppCard(
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
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.inkMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${job.employer} • ${job.location}',
                            style: const TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
          if (showMatch) ...[
            const SizedBox(height: AppSpacing.xs),
            _MatchMeterBar(score: item.matchScore),
          ],
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 11,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 2),
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
        ],
      ),
    );

    if (!isTopMatch) return card;

    // Extra top padding gives the ribbon (positioned above the card's own
    // top edge) room to render without being clipped by the list's
    // spacing above it.
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          const Positioned(top: -10, left: 14, child: _TopMatchRibbon()),
        ],
      ),
    );
  }
}

/// Pinned to the top-left of the #1 For-you card. States an existing fact
/// about the list (For-you is already sorted by [JobListItem.matchScore])
/// rather than a new claim, and is only ever attached when that's true --
/// see `isTopMatch` on [_JobCard].
class _TopMatchRibbon extends StatelessWidget {
  const _TopMatchRibbon();

  @override
  Widget build(BuildContext context) {
    return AppAccentPill(
      icon: Icons.star_rounded,
      label: 'Top match for you',
      background: AppColors.brand,
      foreground: Colors.white,
      iconSize: 12,
      fontSize: 10,
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.18),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      semanticLabel: 'Top match for you',
    );
  }
}

class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.employer, required this.isFlora});

  final String employer;
  final bool isFlora;

  @override
  Widget build(BuildContext context) {
    return AppInitialsAvatar(
      name: employer,
      circular: false,
      background: isFlora ? AppColors.brandSoft : AppColors.infoSoft,
      foreground: isFlora ? AppColors.brand : AppColors.info,
    );
  }
}

/// A compact two-line stat (percentage on top, "MATCH" below) rather than
/// a single-line "N% match" pill -- reads more like a scorecard number at
/// a glance. Same [JobListItem.matchScore] value, same isTop threshold and
/// brand/accent colour logic as before, just re-laid-out.
class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final isTop = score >= 85;
    final tone = isTop ? AppColors.brand : AppColors.accent;
    return Semantics(
      label: '$score percent match',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: isTop ? AppColors.brandSoft : AppColors.accentSoft,
          borderRadius: AppRadius.smallBorder,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$score%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tone,
                height: 1,
              ),
            ),
            Text(
              'MATCH',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: tone,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin horizontal meter that visualises the same [JobListItem.matchScore]
/// the badge above already shows as a number -- not a new figure, just a
/// second read of it. Only rendered on the For-you tab (`showMatch`),
/// matching where the badge itself is shown.
class _MatchMeterBar extends StatelessWidget {
  const _MatchMeterBar({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final isTop = score >= 85;
    return AppMeterBar(
      value: score / 100,
      height: 4,
      fillColor: isTop ? AppColors.brand : AppColors.accent,
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
    if (prefersReducedMotion(context)) {
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
          OutlinedButton.icon(
            onPressed: () => _openExternalListing(context, applyUrl),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('View original listing on $sourceName'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () => _openExternalListing(context, applyUrl),
            child: Text('Apply on $sourceName'),
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

/// A linear progress bar up top (the standard Material "the page itself is
/// loading" signal) plus skeleton cards below. Past a grace period, the
/// status line starts counting elapsed seconds -- the same reassurance
/// `BackendWarmupBanner` gives at sign-in, needed here too since a cold
/// serverless instance can make this screen sit in this state for real
/// seconds, not milliseconds, and a still shimmer with no elapsed-time cue
/// reads as frozen rather than working.
class _JobsLoadingView extends StatelessWidget {
  const _JobsLoadingView();

  // Previously three competing loading affordances at once (an
  // indeterminate LinearProgressIndicator, a separate spinning
  // CircularProgressIndicator + status text, and skeleton placeholders) --
  // real user report: "user seems clueless when both keep loading."
  // AppLoadingProgressBar now owns the single progress signal + status
  // text (including its own grace-period escalation, previously
  // duplicated here as a StatefulWidget); skeletons stay, since they serve
  // a different purpose (previewing content shape) rather than competing
  // as a second "is it working?" signal.
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const AppLoadingProgressBar(
          label: 'Finding jobs for you…',
          slowConnectionLabel:
              'Still finding jobs for you — this can take a moment on a '
              'slow connection.',
          showPercent: true,
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
