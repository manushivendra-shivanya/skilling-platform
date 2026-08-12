import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/networking/domain/networking_repository.dart';
import 'package:candidate_mobile/features/networking/presentation/my_connections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNetworkingRepository implements NetworkingRepository {
  _FakeNetworkingRepository({required this.overview});

  ConnectionsOverview overview;
  final respondedTo = <String, bool>{};
  final withdrawnIds = <String>[];
  final blockedCandidateIds = <String>[];

  @override
  Future<Result<ConnectionsOverview>> listConnections() async =>
      Success(overview);

  @override
  Future<Result<void>> respondToConnection(
    String connectionId,
    bool accept,
  ) async {
    respondedTo[connectionId] = accept;
    return const Success(null);
  }

  @override
  Future<Result<void>> withdrawConnection(String connectionId) async {
    withdrawnIds.add(connectionId);
    return const Success(null);
  }

  @override
  Future<Result<void>> blockCandidate(String candidateId) async {
    blockedCandidateIds.add(candidateId);
    return const Success(null);
  }

  @override
  Future<Result<void>> unblockCandidate(String candidateId) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<DiscoveredCandidate>>> discover() async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> sendConnectionRequest(
    String recipientCandidateId,
  ) async => throw UnimplementedError();

  @override
  Future<Result<NetworkingProfile>> getMyProfile() async =>
      throw UnimplementedError();

  @override
  Future<Result<NetworkingProfile>> publishProfile({
    required String fullName,
    required String headline,
    required String city,
    required String state,
    required List<String> preferredRoles,
    required bool discoverable,
  }) async => throw UnimplementedError();
}

final _incoming = ConnectionSummary(
  id: 'conn-incoming',
  status: ConnectionStatus.pending,
  direction: ConnectionDirection.incoming,
  otherCandidateId: 'candidate-2',
  otherCandidate: OtherCandidateSummary(
    fullName: 'Priya Verma',
    headline: 'Inventory Executive',
    city: '',
    state: '',
  ),
  createdAt: DateTime(2026, 8, 12),
);

void main() {
  Future<void> pump(WidgetTester tester, _FakeNetworkingRepository repo) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [networkingRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: MyConnectionsScreen()),
      ),
    );
  }

  testWidgets('shows an empty state with no connections at all', (
    tester,
  ) async {
    final repo = _FakeNetworkingRepository(
      overview: const ConnectionsOverview.empty(),
    );
    await pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('No connections yet'), findsOneWidget);
  });

  testWidgets('accepting an incoming request calls respondToConnection', (
    tester,
  ) async {
    final repo = _FakeNetworkingRepository(
      overview: ConnectionsOverview(
        accepted: [],
        incomingPending: [_incoming],
        outgoingPending: [],
      ),
    );
    await pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Requests for you'), findsOneWidget);
    expect(find.text('Priya Verma'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pumpAndSettle();

    expect(repo.respondedTo, {'conn-incoming': true});
  });

  testWidgets('blocking a connected candidate calls blockCandidate', (
    tester,
  ) async {
    final accepted = ConnectionSummary(
      id: 'conn-accepted',
      status: ConnectionStatus.accepted,
      direction: ConnectionDirection.outgoing,
      otherCandidateId: 'candidate-3',
      otherCandidate: OtherCandidateSummary(
        fullName: 'Kiran Patel',
        headline: 'Warehouse Associate',
        city: '',
        state: '',
      ),
      createdAt: DateTime(2026, 8, 12),
    );
    final repo = _FakeNetworkingRepository(
      overview: ConnectionsOverview(
        accepted: [accepted],
        incomingPending: [],
        outgoingPending: [],
      ),
    );
    await pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Kiran Patel'), findsOneWidget);

    // Block is destructive (a FilledButton styled with the error color),
    // not the plain OutlinedButton secondary actions elsewhere use --
    // see the widget's own comment for why.
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    expect(repo.blockedCandidateIds, ['candidate-3']);
    expect(find.textContaining('Blocked'), findsOneWidget);
  });
}
