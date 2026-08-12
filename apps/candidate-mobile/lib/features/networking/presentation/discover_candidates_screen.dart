import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_initials_avatar.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../domain/networking_repository.dart';

/// Candidates matched by overlapping preferred roles -- see
/// `NetworkingService.discover`. Reciprocal by design: reaching this
/// screen at all already means the candidate turned their own
/// discoverability on (the "not discoverable yet" error the backend
/// returns otherwise surfaces here as a plain, actionable error state).
class DiscoverCandidatesScreen extends ConsumerStatefulWidget {
  const DiscoverCandidatesScreen({super.key});

  @override
  ConsumerState<DiscoverCandidatesScreen> createState() =>
      _DiscoverCandidatesScreenState();
}

class _DiscoverCandidatesScreenState
    extends ConsumerState<DiscoverCandidatesScreen> {
  late Future<Result<List<DiscoveredCandidate>>> _future;
  final _requested = <String>{};

  @override
  void initState() {
    super.initState();
    _future = ref.read(networkingRepositoryProvider).discover();
  }

  void _reload() {
    setState(() {
      _future = ref.read(networkingRepositoryProvider).discover();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover candidates')),
      body: SafeArea(
        child: FutureBuilder<Result<List<DiscoveredCandidate>>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: AppLoadingProgressBar(label: 'Finding candidates…'),
              );
            }
            return snapshot.data!.when(
              success: (candidates) => _buildList(candidates),
              failure: (failure) => AppErrorState(
                title: 'Could not load candidates',
                message: failure.message,
                onAction: _reload,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<DiscoveredCandidate> candidates) {
    if (candidates.isEmpty) {
      return const AppEmptyState(
        title: 'No matches yet',
        message:
            'No other discoverable candidates share your preferred roles '
            'right now. Check back later.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: candidates.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _CandidateCard(
        candidate: candidates[index],
        requested: _requested.contains(candidates[index].candidateId),
        onConnect: () => _connect(candidates[index]),
      ),
    );
  }

  Future<void> _connect(DiscoveredCandidate candidate) async {
    final result = await ref
        .read(networkingRepositoryProvider)
        .sendConnectionRequest(candidate.candidateId);
    if (!mounted) return;
    result.when(
      success: (_) {
        setState(() => _requested.add(candidate.candidateId));
        showAppSnackBar(
          context: context,
          message: 'Connection request sent to ${candidate.fullName}.',
          tone: AppMessageTone.success,
        );
      },
      failure: (failure) => showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.requested,
    required this.onConnect,
  });

  final DiscoveredCandidate candidate;
  final bool requested;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppInitialsAvatar(name: candidate.fullName, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  candidate.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (candidate.headline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(candidate.headline),
          ],
          if (candidate.city.isNotEmpty || candidate.state.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              [
                candidate.city,
                candidate.state,
              ].where((part) => part.isNotEmpty).join(', '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final role in candidate.sharedRoles)
                AppStatusChip(label: role, tone: AppChipTone.info),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: requested ? 'Request sent' : 'Connect',
            onPressed: requested ? null : onConnect,
          ),
        ],
      ),
    );
  }
}
