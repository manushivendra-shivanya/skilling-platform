import 'package:candidate_mobile/core/widgets/app_progress.dart';
import 'package:candidate_mobile/features/onboarding/presentation/pre_onboarding_step_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// Covers the design audit's header/progress/brand-mark unification across
/// the 4 screens between Welcome and the onboarding wizard: Language,
/// Sign-in choice, Email entry, OTP entry. Welcome is deliberately excluded
/// -- see this fix's other doc comments for why.
void main() {
  Future<void> goToLanguage(WidgetTester tester) async {
    await tester.pumpCandidateApp();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your language'));
    await tester.pumpAndSettle();
  }

  Future<void> goToSignInChoice(WidgetTester tester) async {
    await goToLanguage(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> goToEmailEntry(WidgetTester tester) async {
    await goToSignInChoice(tester);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
  }

  Future<void> goToOtpEntry(WidgetTester tester) async {
    await goToEmailEntry(tester);
    await tester.enterText(
      find.bySemanticsLabel('Email address'),
      'candidate@example.com',
    );
    await tester.ensureVisible(find.text('Send development code'));
    await tester.tap(find.text('Send development code'));
    await tester.pump();
    // Not `pumpAndSettle()`: OTP's countdown starts a `Timer.periodic` that
    // never stops on its own, which `pumpAndSettle` would wait on forever.
    // 800ms is enough to clear the push transition itself (default
    // ~300ms) -- short of that, Email's screen is still mid-transition
    // and this test's own widget-count assertions below see both Email's
    // and OTP's content at once.
    await tester.pump(const Duration(milliseconds: 800));
  }

  group('AppBar titles', () {
    testWidgets('Language shows its title', (tester) async {
      await goToLanguage(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Language / भाषा'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Sign-in choice shows a title -- was a bare AppBar', (
      tester,
    ) async {
      await goToSignInChoice(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Sign in'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Email entry shows its title', (tester) async {
      await goToEmailEntry(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Email sign-in'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('OTP entry shows its title', (tester) async {
      await goToOtpEntry(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Verify OTP'),
        ),
        findsOneWidget,
      );
    });
  });

  group('brand mark', () {
    testWidgets('recurs at one consistent size on all 4 screens', (
      tester,
    ) async {
      await goToLanguage(tester);
      expect(find.byType(PreOnboardingBrandMark), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(PreOnboardingBrandMark), findsOneWidget);

      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      expect(find.byType(PreOnboardingBrandMark), findsOneWidget);

      await tester.enterText(
        find.bySemanticsLabel('Email address'),
        'candidate@example.com',
      );
      await tester.ensureVisible(find.text('Send development code'));
      await tester.tap(find.text('Send development code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(PreOnboardingBrandMark), findsOneWidget);

      // `PreOnboardingBrandMark` has no per-instance size parameter -- one
      // shared constant is what every screen's mark renders at, so
      // checking it once here covers every instance above.
      expect(PreOnboardingBrandMark.markSize, greaterThanOrEqualTo(32));
      expect(PreOnboardingBrandMark.markSize, lessThanOrEqualTo(36));
    });
  });

  group('step-progress indicator', () {
    testWidgets('Language shows step 1 of the shared 2-step prefix', (
      tester,
    ) async {
      await goToLanguage(tester);
      final progress = tester.widget<AppProgress>(find.byType(AppProgress));
      expect(progress.detail, 'Step 1 of 2');
      expect(progress.value, 1 / 2);
    });

    testWidgets(
      'Sign-in choice shows no progress number -- the total is genuinely '
      'undecided until the candidate picks Email or Google',
      (tester) async {
        await goToSignInChoice(tester);
        expect(find.byType(AppProgress), findsNothing);
      },
    );

    testWidgets('Email shows step 3 of the real 4-step email-path total', (
      tester,
    ) async {
      await goToEmailEntry(tester);
      final progress = tester.widget<AppProgress>(find.byType(AppProgress));
      expect(progress.detail, 'Step 3 of 4');
      expect(progress.value, 3 / 4);
    });

    testWidgets('OTP shows step 4 of 4 -- the last email-path step', (
      tester,
    ) async {
      await goToOtpEntry(tester);
      final progress = tester.widget<AppProgress>(find.byType(AppProgress));
      expect(progress.detail, 'Step 4 of 4');
      expect(progress.value, 1.0);
    });
  });
}
