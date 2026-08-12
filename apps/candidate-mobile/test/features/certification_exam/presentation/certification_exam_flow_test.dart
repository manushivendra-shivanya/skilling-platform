import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:candidate_mobile/features/sector_pack/presentation/sector_pack_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

class _FakeCertificationExamRepository implements CertificationExamRepository {
  @override
  Future<Result<CertificationExam>> loadExam() async => Success(_exam());
}

CertificationExam _exam() {
  return const CertificationExam(
    id: 'exam-1',
    title: 'Warehouse Operations Certification',
    version: '1',
    description: 'A short cumulative check.',
    timeLimit: Duration(minutes: 5),
    passThresholdPercent: 50,
    questions: [
      CertificationExamQuestion(
        id: 'q1',
        competencyId: 'tag-a',
        prompt: 'What should happen first?',
        options: [
          ExamAnswerOption(
            id: 'right',
            label: 'The correct action',
            feedback: 'Correct.',
          ),
          ExamAnswerOption(
            id: 'wrong',
            label: 'The incorrect action',
            feedback: 'Incorrect.',
          ),
        ],
        correctOptionId: 'right',
      ),
      CertificationExamQuestion(
        id: 'q2',
        competencyId: 'tag-b',
        prompt: 'What should happen next?',
        options: [
          ExamAnswerOption(
            id: 'right',
            label: 'The correct next step',
            feedback: 'Correct.',
          ),
          ExamAnswerOption(
            id: 'wrong',
            label: 'The incorrect next step',
            feedback: 'Incorrect.',
          ),
        ],
        correctOptionId: 'right',
      ),
    ],
  );
}

/// [MockLearningRepository]'s fixed unit titles -- certification now
/// unlocks only once every lesson unit is completed (see
/// `isCertificationEligible` in `certification_exam_section.dart`), so
/// these tests have to clear all three before the exam card is reachable.
const _lessonTitles = [
  'Inventory accuracy basics',
  'When and how to escalate',
  'Understanding dispatch priority',
];

Future<void> _completeAllLessons(WidgetTester tester) async {
  for (final title in _lessonTitles) {
    await tester.scrollUntilVisible(
      find.text(title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  }
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
      initialDraft: _completedDraft(),
    );
  });

  testWidgets('shows the exam card in the Learn tab', (tester) async {
    // The merged Learn/Practise tab adds a sub-tab bar above the content,
    // which the default 800x600 test surface no longer has room for.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      certificationExamRepository: _FakeCertificationExamRepository(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();
    await _completeAllLessons(tester);
    await tester.tap(find.text('Certification'));
    await tester.pumpAndSettle();
    // The exam's title also matches the section header above the card
    // ("Warehouse Operations Certification"), so scroll to something that
    // only appears once instead.
    await tester.scrollUntilVisible(
      find.text('Start certification exam'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Warehouse Operations Certification'), findsWidgets);
    expect(find.textContaining('2Q'), findsOneWidget);
    expect(find.text('Start certification exam'), findsOneWidget);
  });

  testWidgets(
    'completes a passing attempt end to end and shows the pass result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
        certificationExamRepository: _FakeCertificationExamRepository(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Train'));
      await tester.pumpAndSettle();
      await _completeAllLessons(tester);
      await tester.tap(find.text('Certification'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Start certification exam'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Start certification exam'));
      // The exam screen starts a periodic countdown timer -- pumpAndSettle
      // would spin forever against it, so every step below uses explicit
      // pumps instead, until the attempt is recorded and the timer is
      // cancelled by navigating away. The push transition itself still
      // needs its animation duration pumped through.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Question 1 of 2'), findsOneWidget);
      await tester.tap(find.text('The correct action'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Question 2 of 2'), findsOneWidget);
      await tester.tap(find.text('The correct next step'));
      await tester.pump();
      expect(find.text('2 of 2 questions answered'), findsOneWidget);

      await tester.tap(find.text('Submit exam'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Passed'), findsOneWidget);
      expect(find.textContaining('100%'), findsWidgets);
      expect(
        find.textContaining('Career Passport has been updated'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'exam option rows use drawn SectorIcons, not bare Material icons',
    (tester) async {
      await _openExamQuestionOne(tester, sessions, onboarding);

      expect(find.text('Question 1 of 2'), findsOneWidget);
      // Both options start unselected.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SectorIcon &&
              widget.glyph == SectorGlyph.radioUnselected,
        ),
        findsNWidgets(2),
      );
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);

      await tester.tap(find.text('The correct action'));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SectorIcon && widget.glyph == SectorGlyph.radioSelected,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SectorIcon &&
              widget.glyph == SectorGlyph.radioUnselected,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    },
  );

  testWidgets(
    'an exam option row is independently reachable and activatable via semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _openExamQuestionOne(tester, sessions, onboarding);

      expect(
        find.bySemanticsLabel('The correct action. Not selected'),
        findsOneWidget,
      );
      // Tapping through the semantics-labelled node (not just the row's
      // text) is what regresses if `excludeSemantics: true` is added
      // without also repeating `onTap` on the outer Semantics node -- see
      // the same fix already shipped on practice_screen.dart's
      // `_DemoOptionCard`.
      await tester.tap(
        find.bySemanticsLabel('The correct action. Not selected'),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('The correct action. Selected'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );
}

/// Common setup for the two option-row restyle tests below: reaches the
/// exam's first question screen the same way the passing-attempt flow test
/// above does, using explicit pumps rather than `pumpAndSettle` because the
/// exam screen's periodic countdown timer never settles.
Future<void> _openExamQuestionOne(
  WidgetTester tester,
  InMemoryCandidateSessionRepository sessions,
  InMemoryCandidateOnboardingRepository onboarding,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpCandidateApp(
    candidateSessionRepository: sessions,
    candidateOnboardingRepository: onboarding,
    certificationExamRepository: _FakeCertificationExamRepository(),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Train'));
  await tester.pumpAndSettle();
  await _completeAllLessons(tester);
  await tester.tap(find.text('Certification'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Start certification exam'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Start certification exam'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

CandidateOnboardingDraft _completedDraft() {
  final acceptedAt = DateTime.utc(2026, 7, 27);
  return CandidateOnboardingDraft(
    currentStep: 10,
    goal: CandidateGoal.findJob,
    fullName: 'Asha Kumari',
    city: 'Lucknow',
    state: 'Uttar Pradesh',
    pinCode: '226001',
    education: EducationLevel.twelfthPass,
    experience: ExperienceLevel.fresher,
    preferredRoles: const {LogisticsRole.warehouseAssociate},
    consents: {
      OnboardingConsentVersions.termsPurpose: ConsentAcceptance(
        purpose: OnboardingConsentVersions.termsPurpose,
        version: OnboardingConsentVersions.termsVersion,
        acceptedAt: acceptedAt,
      ),
      OnboardingConsentVersions.privacyPurpose: ConsentAcceptance(
        purpose: OnboardingConsentVersions.privacyPurpose,
        version: OnboardingConsentVersions.privacyVersion,
        acceptedAt: acceptedAt,
      ),
    },
    isCompleted: true,
  );
}
