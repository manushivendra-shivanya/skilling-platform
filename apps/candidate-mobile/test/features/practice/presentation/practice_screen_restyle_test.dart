// Covers the sector-pack restyle of Practice's scored-simulation wizard,
// result screen (both pass and fail/below-threshold), the inventory demo,
// and the "Recommended practice" entry card -- see
// docs/26-sector-pack-rollout.md's dogfooding log for this pass's notes.
// The happy-path pass flow ('100%', evidence persisted) is already covered
// by phase_two_flow_test.dart; this file covers the states that weren't
// exercised anywhere yet.
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/intelligence/data/secure_candidate_intelligence_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:candidate_mobile/features/sector_pack/presentation/sector_pack_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  late InMemoryCandidateSessionRepository sessions;
  late InMemoryCandidateOnboardingRepository onboarding;
  late InMemoryCandidateIntelligenceRepository intelligence;

  setUp(() {
    sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'restyle-candidate',
        isAuthenticated: true,
      ),
    );
    onboarding = InMemoryCandidateOnboardingRepository(
      initialDraft: const CandidateOnboardingDraft(
        currentStep: 10,
        isCompleted: true,
      ),
    );
    intelligence = InMemoryCandidateIntelligenceRepository();
  });

  Future<void> openPractise(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      candidateIntelligenceRepository: intelligence,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a below-threshold scored simulation shows the fail-toned result card',
    (tester) async {
      await openPractise(tester);
      await tester.tap(find.text('Scored inventory simulation'));
      await tester.pumpAndSettle();

      // Wrong first action -> low accuracy; discard + ignore -> low
      // escalation/sequence too. Also exercises the secondary
      // (translucent-outline) wizard option button.
      await tester.tap(find.text('Overwrite the system quantity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard the original record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave it for the next shift'));
      await tester.pumpAndSettle();

      expect(find.text('33%'), findsOneWidget);
      expect(intelligence.state.simulationScores.single.totalScore, 33);

      await tester.tap(find.text('Return to practice'));
      await tester.pumpAndSettle();
      expect(find.text('Scored inventory simulation'), findsOneWidget);
    },
  );

  testWidgets(
    'the scored result card\'s "Return to practice" button is independently '
    'reachable and activatable via semantics, not merged into the score '
    'breakdown text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openPractise(tester);
      await tester.tap(find.text('Scored inventory simulation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recount the physical stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preserve both values and count notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escalate the documented exception'));
      await tester.pumpAndSettle();

      // Before this fix, nothing in the result card declared its own
      // semantics boundary, so Flutter's default merge combined the score,
      // explanation, every dimension row, and the improvement note *and*
      // this button into one node -- a real debugDumpSemanticsTree() dump
      // confirmed the button's own label only reached the tree as the tail
      // of that giant string, with no `button` role. It must now be its
      // own clean node.
      final buttonFinder = find.bySemanticsLabel('Return to practice');
      expect(buttonFinder, findsOneWidget);
      final buttonNode = tester.getSemantics(buttonFinder);
      expect(buttonNode.flagsCollection.isButton, isTrue);
      expect(buttonNode.label, 'Return to practice');

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(find.text('Scored inventory simulation'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'recording a demo network interruption mid-wizard shows the snackbar and does not advance the step',
    (tester) async {
      await openPractise(tester);
      await tester.tap(find.text('Scored inventory simulation'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 3 · VERIFY'), findsOneWidget);
      await tester.tap(
        find.text('Record a demo network interruption'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(
        find.text(
          'Technical event recorded separately with zero score penalty.',
        ),
        findsOneWidget,
      );
      // Still on step 1 -- a technical event isn't a decision.
      expect(find.text('STEP 1 OF 3 · VERIFY'), findsOneWidget);
    },
  );

  testWidgets(
    'the inventory demo shows drawn radio glyphs and tone-appropriate feedback for a wrong pick',
    (tester) async {
      await openPractise(tester);
      await tester.tap(find.text('Inventory discrepancy'));
      await tester.pumpAndSettle();

      // All three start unselected.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SectorIcon &&
              widget.glyph == SectorGlyph.radioUnselected,
        ),
        findsNWidgets(3),
      );

      await tester.tap(find.text('Change the system quantity immediately'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SectorIcon && widget.glyph == SectorGlyph.radioSelected,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Try again: safe operations preserve records'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Recount, preserve records, and escalate the mismatch'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Good practice'), findsOneWidget);

      await tester.tap(find.text('Return to practice'));
      await tester.pumpAndSettle();

      // The demo entry card now reads Completed/RETRY, matching how the 4
      // real missions show their own completed state.
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('RETRY'), findsWidgets);
    },
  );

  testWidgets('Catalogue rows use drawn SectorIcons, not bare Material icons', (
    tester,
  ) async {
    await openPractise(tester);
    await tester.scrollUntilVisible(
      find.text('Dispatch prioritisation'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is SectorIcon && widget.glyph == SectorGlyph.truck,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SectorIcon && widget.glyph == SectorGlyph.mic,
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
    expect(find.byIcon(Icons.record_voice_over_outlined), findsNothing);
  });
}
