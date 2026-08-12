import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../domain/networking_repository.dart';

/// Accepted connections, plus requests waiting on either side. View-only
/// -- there's no messaging here, see
/// `apps/api/src/networking/networking.service.ts`'s doc comment for why
/// that's deliberate. Block is the one safety action a candidate can take
/// on a connection unilaterally.
class MyConnectionsScreen extends ConsumerStatefulWidget {
  const MyConnectionsScreen({super.key});

  @override
  ConsumerState<MyConnectionsScreen> createState() =>
      _MyConnectionsScreenState();
}

class _MyConnectionsScreenState extends ConsumerState<MyConnectionsScreen> {
  late Future<Result<ConnectionsOverview>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(networkingRepositoryProvider).listConnections();
  }

  void _reload() {
    setState(() {
      _future = ref.read(networkingRepositoryProvider).listConnections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My connections')),
      body: SafeArea(
        child: FutureBuilder<Result<ConnectionsOverview>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: AppLoadingProgressBar(label: 'Loading connections…'),
              );
            }
            return snapshot.data!.when(
              success: _buildOverview,
              failure: (failure) => AppErrorState(
                title: 'Could not load connections',
                message: failure.message,
                onAction: _reload,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverview(ConnectionsOverview overview) {
    final isEmpty =
        overview.accepted.isEmpty &&
        overview.incomingPending.isEmpty &&
        overview.outgoingPending.isEmpty;
    if (isEmpty) {
      return const AppEmptyState(
        title: 'No connections yet',
        message:
            'Requests you send or receive, and candidates you connect '
            'with, will show up here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (overview.incomingPending.isNotEmpty) ...[
          Text(
            'Requests for you',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final connection in overview.incomingPending)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ConnectionCard(
                connection: connection,
                actions: [
                  AppButton(
                    label: 'Accept',
                    onPressed: () => _respond(connection, true),
                  ),
                  AppButton(
                    label: 'Decline',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _respond(connection, false),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (overview.outgoingPending.isNotEmpty) ...[
          Text('Sent requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final connection in overview.outgoingPending)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ConnectionCard(
                connection: connection,
                actions: [
                  AppButton(
                    label: 'Withdraw',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _withdraw(connection),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (overview.accepted.isNotEmpty) ...[
          Text('Connected', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final connection in overview.accepted)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ConnectionCard(
                connection: connection,
                actions: [
                  AppButton(
                    label: 'Disconnect',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _withdraw(connection),
                  ),
                  AppButton(
                    label: 'Block',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _block(connection),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _respond(ConnectionSummary connection, bool accept) async {
    final result = await ref
        .read(networkingRepositoryProvider)
        .respondToConnection(connection.id, accept);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (failure) => showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      ),
    );
  }

  Future<void> _withdraw(ConnectionSummary connection) async {
    final result = await ref
        .read(networkingRepositoryProvider)
        .withdrawConnection(connection.id);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (failure) => showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      ),
    );
  }

  Future<void> _block(ConnectionSummary connection) async {
    final result = await ref
        .read(networkingRepositoryProvider)
        .blockCandidate(connection.otherCandidateId);
    if (!mounted) return;
    result.when(
      success: (_) {
        showAppSnackBar(
          context: context,
          message: 'Blocked. They cannot send you new requests.',
          tone: AppMessageTone.success,
        );
        _reload();
      },
      failure: (failure) => showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection, required this.actions});

  final ConnectionSummary connection;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final other = connection.otherCandidate;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            other?.fullName ?? 'A candidate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (other != null && other.headline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(other.headline),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // AppButton defaults to expand: true (fills its parent's
              // width), so it needs a bounded-width parent here -- same
              // reason NetworkingSection wraps its two buttons in
              // Expanded rather than placing them straight in a Row.
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
