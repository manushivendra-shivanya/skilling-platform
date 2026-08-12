import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_language.dart';
import 'package:candidate_mobile/features/onboarding/domain/onboarding_entry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'selects and preserves Hindi through forward and back navigation',
    (tester) async {
      final analytics = InMemoryAnalyticsTracker();
      final semantics = tester.ensureSemantics();

      await tester.pumpCandidateApp(analyticsTracker: analytics);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose your language'));
      await tester.pumpAndSettle();

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('आप कैसे आगे बढ़ना चाहेंगे?'), findsOneWidget);
      expect(find.text('ईमेल से आगे बढ़ें'), findsOneWidget);
      expect(
        find.text('जल्द उपलब्ध होगा — अभी सेट अप नहीं है'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('हिंदी. हिंदी में आगे बढ़ें. Selected'),
        findsOneWidget,
      );
      expect(
        analytics.events.any(
          (event) =>
              event.name == 'language_selected' &&
              event.properties['language_code'] == CandidateLanguage.hindi.code,
        ),
        isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets('opens development email sign-in and policy summaries', (
    tester,
  ) async {
    await tester.pumpCandidateApp();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Planned — not configured yet'), findsOneWidget);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy summary'), findsOneWidget);
    expect(find.textContaining('We collect only'), findsOneWidget);
  });

  testWidgets('shows a recoverable language loading error', (tester) async {
    await tester.pumpCandidateApp(
      onboardingEntryRepository: const _FailingOnboardingEntryRepository(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your language'));
    await tester.pumpAndSettle();

    expect(find.text('We could not load your language'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Hindi sign-in copy supports narrow scaled layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpCandidateApp();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose your language'));
    await tester.tap(find.text('Choose your language'));
    await tester.pumpAndSettle();
    // Language's brand mark + step-progress header now shares one
    // scrollable region with the language list (see
    // `language_selection_screen.dart`), so on this narrow, heavily scaled
    // layout Hindi's card can sit far enough down that it isn't even built
    // yet -- `ensureVisible` alone only scrolls an already-built widget
    // into view, it can't discover one that hasn't mounted. `scrollUntilVisible`
    // (same tool `candidate_onboarding_flow_test.dart` already reaches for
    // in this situation) scrolls incrementally until it exists.
    await tester.scrollUntilVisible(
      find.text('हिंदी'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('हिंदी'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('आप कैसे आगे बढ़ना चाहेंगे?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FailingOnboardingEntryRepository implements OnboardingEntryRepository {
  const _FailingOnboardingEntryRepository();

  @override
  Future<CandidateLanguage?> readSelectedLanguage() {
    throw StateError('Storage unavailable');
  }

  @override
  Future<void> saveSelectedLanguage(CandidateLanguage language) {
    throw StateError('Storage unavailable');
  }
}
