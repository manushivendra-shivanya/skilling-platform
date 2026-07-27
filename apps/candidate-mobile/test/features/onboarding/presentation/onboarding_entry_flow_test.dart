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
      expect(find.text('फ़ोन नंबर से आगे बढ़ें'), findsOneWidget);
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

  testWidgets('opens development phone sign-in and policy summaries', (
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

    await tester.tap(find.text('Continue with phone'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your mobile number'), findsOneWidget);
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
