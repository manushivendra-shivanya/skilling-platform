// Covers a real screen-reader-accessibility sweep of the Learn tab's 3-way
// segmented bar (learn_and_practice_screen.dart's `_SectorSegmentedTabBar`)
// -- see docs/26-sector-pack-rollout.md's dogfooding log for this pass's
// findings. Before this fix, each segment had no Semantics node of its own
// at all: Flutter's default merge still made it reachable and tappable, but
// the tab's *selected* state was never announced on any segment, ever.
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  late InMemoryCandidateSessionRepository sessions;
  late InMemoryCandidateOnboardingRepository onboarding;

  setUp(() {
    sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'tabbar-candidate',
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
    'each segment announces its selected state and switches tabs via semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();

      final lessonsFinder = find.bySemanticsLabel(
        RegExp(r'^Lessons\. .*\. Tab 1 of 3\.$'),
      );
      final practiseFinder = find.bySemanticsLabel(
        RegExp(r'^Practise\. .*\. Tab 2 of 3\.$'),
      );

      // Lessons starts selected -- its node carries isSelected, Practise's
      // doesn't.
      expect(lessonsFinder, findsOneWidget);
      expect(
        tester.getSemantics(lessonsFinder).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(practiseFinder, findsOneWidget);
      expect(
        tester.getSemantics(practiseFinder).flagsCollection.isSelected,
        Tristate.isFalse,
      );

      // Activating the Practise segment through its semantics node (not
      // just its raw text) is what regresses if a future edit wraps this
      // tab in `excludeSemantics: true` without also repeating `onTap` on
      // the outer Semantics node -- the same class of bug already caught
      // and fixed on practice_screen.dart's `_DemoOptionCard` and
      // certification_exam_screen.dart's `_ExamOptionCard`.
      await tester.tap(practiseFinder);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(practiseFinder).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        tester.getSemantics(lessonsFinder).flagsCollection.isSelected,
        Tristate.isFalse,
      );
      // Practise's own content (e.g. the scored simulation entry) is now
      // showing, confirming the tap actually switched screens, not just
      // flipped the visual indicator.
      expect(find.text('Scored inventory simulation'), findsOneWidget);

      semantics.dispose();
    },
  );
}
