// Learning and Practice are the two major destinations that skipped the
// large-text-scale convention every other primary flow already follows
// (see workplace_operational_screens_test.dart, phase_one_shells_test.dart,
// onboarding_entry_flow_test.dart, app_button_test.dart). This closes that
// gap: both screens are pumped at a 2x accessibility text scale -- the
// largest Android system font-scale step -- through the same navigation
// path a real candidate uses, and asserted overflow-free.
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// [WidgetController.scrollUntilVisible]'s default 300px step overshoots
/// past short-lived cache windows in a tall, 2x-text-scaled ListView --
/// verified empirically: the target renders and stays stable once reached,
/// but a 300px step can jump clean over the range where it's built. Finer
/// 150px steps reach it reliably.
Future<void> _scrollUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pump();
  }
  expect(finder, findsWidgets, reason: 'not found after scrolling');
}

void main() {
  late InMemoryCandidateSessionRepository sessions;
  late InMemoryCandidateOnboardingRepository onboarding;

  setUp(() {
    sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'dev-candidate-3210',
        isAuthenticated: true,
      ),
    );
    onboarding = InMemoryCandidateOnboardingRepository(
      initialDraft: const CandidateOnboardingDraft(
        currentStep: 10,
        isCompleted: true,
      ),
    );
  });

  testWidgets(
    'Lessons tab renders at 2x text scale without overflow',
    (tester) async {
      // A common small-Android baseline width -- tight enough that the
      // lesson row's title, meta line, and Wrap-ped action buttons are
      // genuinely under pressure at 2x, not just coasting on extra room.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();

      expect(find.text('Your logistics pathway'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // At 2x text scale the header and progress copy push the lesson list
      // beyond ListView's initial build+cache extent, so the cards aren't
      // in the tree yet -- scroll drives the sliver to build them.
      // Note: pass the finder without `.first` -- `.first` reduces eagerly
      // and throws StateError on zero matches instead of evaluating empty,
      // which breaks the "not found yet, keep scrolling" check below.
      await _scrollUntilFound(tester, find.text('Open lesson'));
      expect(tester.takeException(), isNull);
      // Found means "built into the sliver's cache", not necessarily
      // "within the visible viewport" -- nudge it fully into view before
      // tapping so the hit test lands on it, not just past its edge.
      await tester.ensureVisible(find.text('Open lesson').first);

      // Open a lesson: the bottom sheet is its own dense text layout
      // (checkpoint question + feedback card) and deserves the same check.
      // warnIfMissed: false -- ensureVisible's scroll animation can still
      // leave the target a few px outside the exact hit-test bounds in the
      // test harness; the tap itself lands correctly either way.
      await tester.tap(find.text('Open lesson').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Inventory accuracy basics'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Practise tab renders at 2x text scale without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Recommended practice'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recommended practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
