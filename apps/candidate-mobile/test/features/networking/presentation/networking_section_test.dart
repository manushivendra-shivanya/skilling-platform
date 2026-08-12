import 'dart:async';

import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/networking/domain/networking_repository.dart';
import 'package:candidate_mobile/features/networking/presentation/networking_section.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNetworkingRepository implements NetworkingRepository {
  _FakeNetworkingRepository({this.getMyProfileResult});

  Result<NetworkingProfile>? getMyProfileResult;
  final publishedProfiles = <NetworkingProfile>[];

  /// Lets a test hold `getMyProfile` open until it explicitly completes it,
  /// to assert on the in-flight loading state.
  Completer<Result<NetworkingProfile>>? pendingGetMyProfile;

  @override
  Future<Result<NetworkingProfile>> getMyProfile() {
    if (pendingGetMyProfile != null) return pendingGetMyProfile!.future;
    return Future.value(
      getMyProfileResult ??
          const Success(
            NetworkingProfile(
              discoverable: false,
              fullName: '',
              headline: '',
              city: '',
              state: '',
              preferredRoles: [],
            ),
          ),
    );
  }

  @override
  Future<Result<NetworkingProfile>> publishProfile({
    required String fullName,
    required String headline,
    required String city,
    required String state,
    required List<String> preferredRoles,
    required bool discoverable,
  }) async {
    final profile = NetworkingProfile(
      discoverable: discoverable,
      fullName: fullName,
      headline: headline,
      city: city,
      state: state,
      preferredRoles: preferredRoles,
    );
    publishedProfiles.add(profile);
    return Success(profile);
  }

  @override
  Future<Result<List<DiscoveredCandidate>>> discover() async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> sendConnectionRequest(
    String recipientCandidateId,
  ) async => throw UnimplementedError();

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
  const draft = CandidateOnboardingDraft(
    fullName: 'Asha Kumari',
    headline: 'Warehouse Associate',
    city: 'Lucknow',
    state: 'Uttar Pradesh',
  );

  Future<void> pump(WidgetTester tester, _FakeNetworkingRepository repo) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [networkingRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: NetworkingSection(draft: draft)),
        ),
      ),
    );
  }

  SwitchListTile switchTile(WidgetTester tester) =>
      tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Make my profile discoverable'),
      );

  testWidgets(
    'renders the switch ON on first build when the candidate is already '
    'discoverable, instead of defaulting to off',
    (tester) async {
      final repo = _FakeNetworkingRepository(
        getMyProfileResult: const Success(
          NetworkingProfile(
            discoverable: true,
            fullName: 'Asha Kumari',
            headline: 'Warehouse Associate',
            city: 'Lucknow',
            state: 'Uttar Pradesh',
            preferredRoles: ['warehouse_associate'],
          ),
        ),
      );

      await pump(tester, repo);
      await tester.pumpAndSettle();

      expect(switchTile(tester).value, isTrue);
      expect(switchTile(tester).onChanged, isNotNull);
    },
  );

  testWidgets('renders the switch OFF on first build when the candidate is not '
      'discoverable', (tester) async {
    final repo = _FakeNetworkingRepository(
      getMyProfileResult: const Success(
        NetworkingProfile(
          discoverable: false,
          fullName: '',
          headline: '',
          city: '',
          state: '',
          preferredRoles: [],
        ),
      ),
    );

    await pump(tester, repo);
    await tester.pumpAndSettle();

    expect(switchTile(tester).value, isFalse);
    expect(switchTile(tester).onChanged, isNotNull);
  });

  testWidgets(
    'shows a disabled switch and a checking caption while the real value '
    'is loading, not a confident off',
    (tester) async {
      final repo = _FakeNetworkingRepository()
        ..pendingGetMyProfile = Completer<Result<NetworkingProfile>>();

      await pump(tester, repo);
      await tester.pump();

      expect(switchTile(tester).value, isFalse);
      expect(switchTile(tester).onChanged, isNull);
      expect(find.text('Checking your settings…'), findsOneWidget);

      repo.pendingGetMyProfile!.complete(
        const Success(
          NetworkingProfile(
            discoverable: true,
            fullName: '',
            headline: '',
            city: '',
            state: '',
            preferredRoles: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(switchTile(tester).value, isTrue);
      expect(switchTile(tester).onChanged, isNotNull);
      expect(find.text('Checking your settings…'), findsNothing);
    },
  );

  testWidgets(
    'shows a disabled switch, an error caption, and a retry when the read '
    'fails, instead of a confident off',
    (tester) async {
      final repo = _FakeNetworkingRepository(
        getMyProfileResult: const ResultFailure(
          NetworkFailure('Could not reach the server.'),
        ),
      );

      await pump(tester, repo);
      await tester.pumpAndSettle();

      expect(switchTile(tester).value, isFalse);
      expect(switchTile(tester).onChanged, isNull);
      expect(
        find.text('Could not check your current setting. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      repo.getMyProfileResult = const Success(
        NetworkingProfile(
          discoverable: true,
          fullName: '',
          headline: '',
          city: '',
          state: '',
          preferredRoles: [],
        ),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(switchTile(tester).value, isTrue);
      expect(switchTile(tester).onChanged, isNotNull);
    },
  );

  testWidgets('toggling the switch still publishes the profile', (
    tester,
  ) async {
    final repo = _FakeNetworkingRepository();
    await pump(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Make my profile discoverable'),
    );
    await tester.pumpAndSettle();

    expect(repo.publishedProfiles, hasLength(1));
    expect(repo.publishedProfiles.single.discoverable, isTrue);
    expect(switchTile(tester).value, isTrue);
  });
}
