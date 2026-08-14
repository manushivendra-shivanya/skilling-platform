import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/networking/domain/networking_repository.dart';
import 'package:candidate_mobile/features/networking/presentation/discover_candidates_screen.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNetworkingRepository implements NetworkingRepository {
  _FakeNetworkingRepository({this.discoverResult});

  Result<List<DiscoveredCandidate>>? discoverResult;
  final sentRequests = <String>[];

  @override
  Future<Result<List<DiscoveredCandidate>>> discover() async =>
      discoverResult ?? const Success([]);

  @override
  Future<Result<void>> sendConnectionRequest(
    String recipientCandidateId,
  ) async {
    sentRequests.add(recipientCandidateId);
    return const Success(null);
  }

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

  @override
  Future<Result<ConnectionsOverview>> listConnections() async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> respondToConnection(
    String connectionId,
    bool accept,
  ) async => throw UnimplementedError();

  @override
  Future<Result<void>> withdrawConnection(String connectionId) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> blockCandidate(String candidateId) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> unblockCandidate(String candidateId) async =>
      throw UnimplementedError();
}

void main() {
  Future<void> pump(WidgetTester tester, _FakeNetworkingRepository repo) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [networkingRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiscoverCandidatesScreen(),
        ),
      ),
    );
  }

  testWidgets(
    'shows matched candidates and marks a request as sent after connecting',
    (tester) async {
      final repo = _FakeNetworkingRepository(
        discoverResult: const Success([
          DiscoveredCandidate(
            candidateId: 'candidate-2',
            fullName: 'Ravi Singh',
            headline: 'Dispatch Executive',
            city: 'Lucknow',
            state: 'Uttar Pradesh',
            sharedRoles: ['warehouse_associate'],
          ),
        ]),
      );
      await pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Ravi Singh'), findsOneWidget);
      expect(find.text('Dispatch Executive'), findsOneWidget);
      expect(find.text('warehouse_associate'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
      await tester.pumpAndSettle();

      expect(repo.sentRequests, ['candidate-2']);
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.textContaining('Connection request sent'), findsOneWidget);
    },
  );

  testWidgets('shows an empty state when there are no matches', (tester) async {
    final repo = _FakeNetworkingRepository(discoverResult: const Success([]));
    await pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets(
    'shows the discoverability-required error plainly, with a retry',
    (tester) async {
      final repo = _FakeNetworkingRepository(
        discoverResult: const ResultFailure(
          PermissionFailure(
            'Turn on discoverability on your Professional Persona to see '
            'other candidates.',
          ),
        ),
      );
      await pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.textContaining('Turn on discoverability'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
}
