import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/splash/data/mock_app_startup_repository.dart';
import 'package:candidate_mobile/features/splash/domain/app_startup_state.dart';
import 'package:candidate_mobile/features/splash/presentation/app_startup_controller.dart';
import 'package:candidate_mobile/features/splash/presentation/app_startup_screen.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('shows a recoverable startup error and retries', (tester) async {
    final repository = MockAppStartupRepository(
      response: const ResultFailure(
        NetworkFailure('You appear to be offline.'),
      ),
    );

    await tester.pumpCandidateApp(startupRepository: repository);
    await tester.pumpAndSettle();

    expect(find.text('We could not prepare the app'), findsOneWidget);
    // Not the raw 'You appear to be offline.' internal message: AppFailure's
    // own `message` is English-only developer/log text -- the screen shows
    // a localized, generic message keyed off the failure's type instead.
    expect(
      find.text('No internet connection. Check your network and try again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);

    repository.setResponse(const Success(AppStartupState(isLowDataMode: true)));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
  });

  testWidgets('calls onReady once appStartupControllerProvider resolves '
      'after this screen is mounted', (tester) async {
    AppStartupState? readyState;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupRepositoryProvider.overrideWithValue(
            MockAppStartupRepository(),
          ),
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppStartupScreen(onReady: (state) => readyState = state),
        ),
      ),
    );

    expect(readyState, isNull);
    await tester.pumpAndSettle();
    expect(readyState, isNotNull);
  });

  testWidgets(
    'calls onReady even when appStartupControllerProvider was already '
    'resolved before this screen was mounted '
    '(real-device report: a static "Saksham" splash with no progress '
    'indicator, permanently stuck -- this is the AppStartupScreen being '
    'mounted a second time, in the "ready" state from the start, after '
    'appRouterProvider used to rebuild and throw away its old GoRouter '
    'right after Google sign-in; ref.listen never sees a transition into '
    'an already-resolved value, so onReady was never called)',
    (tester) async {
      AppStartupState? readyState;
      final container = ProviderContainer(
        overrides: [
          appStartupRepositoryProvider.overrideWithValue(
            MockAppStartupRepository(),
          ),
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Resolve the controller BEFORE any AppStartupScreen exists, exactly
      // like a provider that was already warmed up (or, on a real device,
      // one that had already resolved once and simply never got torn down)
      // by the time a fresh screen mounts onto it.
      await container.read(appStartupControllerProvider.future);
      expect(
        container.read(appStartupControllerProvider),
        isA<AsyncData<AppStartupState>>(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AppStartupScreen(onReady: (state) => readyState = state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        readyState,
        isNotNull,
        reason:
            'onReady must fire even for a value the provider already held '
            'the instant this screen mounted -- otherwise the screen has '
            'nothing left to react to and sits there forever.',
      );
    },
  );
}
