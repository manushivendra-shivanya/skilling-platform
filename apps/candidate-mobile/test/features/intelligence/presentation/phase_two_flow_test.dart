import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/intelligence/data/secure_candidate_intelligence_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  late InMemoryCandidateIntelligenceRepository intelligence;

  setUp(() {
    intelligence = InMemoryCandidateIntelligenceRepository();
  });

  testWidgets('candidate completes and persists an explainable diagnostic', (
    tester,
  ) async {
    // ensureVisible needs the target actually built first -- at the
    // default 800x600 surface, "Open career diagnostic" is now pushed
    // beyond ListView's build extent by the Home content above it, so
    // find.text matches nothing at all (not just off-screen).
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final analytics = InMemoryAnalyticsTracker();
    await tester.pumpCandidateApp(
      candidateSessionRepository: InMemoryCandidateSessionRepository(
        session: const CandidateSession(
          candidateId: 'phase-two-candidate',
          isAuthenticated: true,
        ),
      ),
      candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(
        initialDraft: const CandidateOnboardingDraft(
          currentStep: 10,
          isCompleted: true,
        ),
      ),
      candidateIntelligenceRepository: intelligence,
      analyticsTracker: analytics,
    );
    await tester.pumpAndSettle();

    // The diagnostic is a one-off setup task, so it lives on the profile
    // tab rather than competing with the daily mission on Home.
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Career diagnostic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Career diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('Find your logistics pathway'), findsOneWidget);
    await tester.tap(find.text('Start diagnostic'));
    await tester.pumpAndSettle();

    for (final option in const [
      'Recount and preserve both records',
      'Isolate, record, and escalate using the SOP',
      'Check SLA, safety, and approved priority rules',
      'Share facts, actions, owner, and outstanding risk',
    ]) {
      await tester.tap(find.text(option));
      await tester.pump();
      await tester.tap(
        find.text(
          option.startsWith('Share') ? 'See my pathway' : 'Next question',
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('Your explainable pathway'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save pathway'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save pathway'));
    await tester.pumpAndSettle();

    expect(intelligence.state.diagnosticResult, isNotNull);
    expect(intelligence.state.evidence, hasLength(4));
    expect(
      analytics.events.map((event) => event.name),
      contains('diagnostic_completed'),
    );
  });

  testWidgets('scored simulation persists evidence and an explanation', (
    tester,
  ) async {
    // The merged Learn/Practise tab adds a sub-tab bar above the content,
    // which the default 800x600 test surface no longer has room for.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpCandidateApp(
      candidateSessionRepository: InMemoryCandidateSessionRepository(
        session: const CandidateSession(
          candidateId: 'phase-two-candidate',
          isAuthenticated: true,
        ),
      ),
      candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(
        initialDraft: const CandidateOnboardingDraft(
          currentStep: 10,
          isCompleted: true,
        ),
      ),
      candidateIntelligenceRepository: intelligence,
    );
    await tester.pumpAndSettle();
    // Practise now lives as a sub-tab inside Learn rather than its own
    // bottom-nav destination.
    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();
    // The scored simulation entry point is now a job-ticket-style
    // SectorTaskCard -- the whole card (its title text) is the tap target,
    // there's no separate "Start scored simulation" button anymore.
    await tester.tap(find.text('Scored inventory simulation'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recount the physical stock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preserve both values and count notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escalate the documented exception'));
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsWidgets);
    expect(find.textContaining('audit trail'), findsOneWidget);
    expect(intelligence.state.simulationScores, hasLength(1));
    expect(intelligence.state.simulationScores.single.totalScore, 100);
    expect(intelligence.state.evidence, hasLength(2));
  });
}
