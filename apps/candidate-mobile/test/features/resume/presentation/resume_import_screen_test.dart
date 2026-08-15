import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/profile_details/data/in_memory_detailed_profile_repository.dart';
import 'package:candidate_mobile/features/profile_details/domain/detailed_candidate_profile.dart';
import 'package:candidate_mobile/features/profile_details/domain/detailed_profile_repository.dart';
import 'package:candidate_mobile/features/resume/domain/resume_parsing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// Covers the post-signup resume-import screen end to end through the real
/// router (same navigation the app performs), not the widget in isolation
/// -- its behaviour is inseparable from `_continueFromAuthenticated`'s
/// currentStep == 0 gate and from where "Skip"/"Confirm" actually lead.
void main() {
  late InMemoryCandidateSessionRepository sessions;

  setUp(() {
    sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'dev-candidate-9911',
        isAuthenticated: true,
      ),
    );
  });

  Future<void> continueToAuthenticated(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to profile setup'));
    await tester.pumpAndSettle();
  }

  /// Fills the resume text, gives consent, and taps Extract -- the button
  /// sits below the fold at the default test viewport, same class of
  /// off-screen-tap issue documented on the onboarding flow test's own
  /// extract-button taps, so this scrolls to it first rather than tapping
  /// blind.
  Future<void> extractResume(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('resume-import-text-field')),
      'Asha Kumari, Warehouse Associate at ABC Logistics, 2 years experience.',
    );
    await tester.ensureVisible(find.text('Use AI to read this text'));
    await tester.tap(find.text('Use AI to read this text'));
    await tester.pump();
    final extractButton = find.byKey(
      const ValueKey('resume-import-extract-button'),
    );
    await Scrollable.ensureVisible(
      tester.element(extractButton),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(extractButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a fresh draft is offered the resume-import screen before the wizard',
    (tester) async {
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(),
      );
      await continueToAuthenticated(tester);

      expect(find.text('Build your profile in seconds'), findsOneWidget);
      expect(find.text('What would you like to achieve?'), findsNothing);
    },
  );

  testWidgets('skip proceeds into the wizard without saving anything', (
    tester,
  ) async {
    final onboarding = InMemoryCandidateOnboardingRepository();
    final profile = InMemoryDetailedProfileRepository();
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      detailedProfileRepository: profile,
    );
    await continueToAuthenticated(tester);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('What would you like to achieve?'), findsOneWidget);
    expect(onboarding.draft.fullName, isEmpty);
    expect(profile.profile.phone, isEmpty);
  });

  testWidgets(
    'confirming an extraction applies it to the draft and the detailed profile',
    (tester) async {
      final onboarding = InMemoryCandidateOnboardingRepository();
      final profile = InMemoryDetailedProfileRepository();
      final parser = _FakeResumeParsingRepository(_fullExtraction);
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
        detailedProfileRepository: profile,
        resumeParsingRepository: parser,
      );
      await continueToAuthenticated(tester);

      await extractResume(tester);

      expect(find.text('What we found'), findsOneWidget);
      expect(find.text('Asha Kumari'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('resume-import-confirm-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('What would you like to achieve?'), findsOneWidget);
      expect(onboarding.draft.fullName, 'Asha Kumari');
      expect(onboarding.draft.city, 'Lucknow');
      expect(onboarding.draft.headline, 'Warehouse Associate');
      expect(profile.profile.phone, '9876543210');
      expect(profile.profile.skills, ['Forklift operation']);
      expect(profile.profile.education, hasLength(1));
      expect(profile.profile.education.single.degree, 'Bachelor of Technology');
      expect(profile.profile.workExperience, hasLength(1));
    },
  );

  testWidgets(
    'a partial save failure keeps the candidate on the screen with a way to continue anyway',
    (tester) async {
      final onboarding = InMemoryCandidateOnboardingRepository();
      final profile = _FailingDetailedProfileRepository();
      final parser = _FakeResumeParsingRepository(_fullExtraction);
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
        detailedProfileRepository: profile,
        resumeParsingRepository: parser,
      );
      await continueToAuthenticated(tester);

      await extractResume(tester);
      await tester.tap(
        find.byKey(const ValueKey('resume-import-confirm-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Some details could not be saved. You can add them later from your profile.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue anyway'), findsOneWidget);
      // The draft write still went through -- only the profile write failed.
      expect(onboarding.draft.fullName, 'Asha Kumari');

      await tester.tap(find.text('Continue anyway'));
      await tester.pumpAndSettle();

      expect(find.text('What would you like to achieve?'), findsOneWidget);
    },
  );
}

final _fullExtraction = ResumeParseResult(
  adapter: 'fake',
  requiresCandidateReview: false,
  fullName: 'Asha Kumari',
  phone: '9876543210',
  email: '',
  city: 'Lucknow',
  headline: 'Warehouse Associate',
  yearsOfExperience: '2 years',
  skills: const ['Forklift operation'],
  education: const [
    EducationEntry(
      id: '',
      institution: 'ABC University',
      degree: 'Bachelor of Technology',
      fieldOfStudy: 'Computer Science',
    ),
  ],
  workExperience: const [
    WorkExperienceEntry(
      id: '',
      title: 'Warehouse Associate',
      company: 'ABC Logistics',
    ),
  ],
  certifications: const [],
  projects: const [],
);

class _FakeResumeParsingRepository implements ResumeParsingRepository {
  _FakeResumeParsingRepository(this._result);

  final ResumeParseResult _result;

  @override
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request) async =>
      Success(_result);
}

/// Fails only the profile-writing calls -- draft saves still go through, so
/// the "partial failure" case (draft applied, profile not) is real, not
/// simulated by failing everything.
class _FailingDetailedProfileRepository implements DetailedProfileRepository {
  @override
  Future<Result<DetailedCandidateProfile>> load(String candidateId) async =>
      Success(DetailedCandidateProfile.empty);

  @override
  Future<Result<void>> saveContactAndSkills(
    String candidateId, {
    required String phone,
    required String email,
    required List<String> skills,
  }) async => const ResultFailure(
    NetworkFailure(
      'This could not be saved. Check your connection and try again.',
    ),
  );

  @override
  Future<Result<void>> upsertWorkExperience(
    String candidateId,
    WorkExperienceEntry entry,
  ) async => const ResultFailure(
    NetworkFailure(
      'This could not be saved. Check your connection and try again.',
    ),
  );

  @override
  Future<Result<void>> deleteWorkExperience(String candidateId, String id) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> upsertEducation(
    String candidateId,
    EducationEntry entry,
  ) async => const ResultFailure(
    NetworkFailure(
      'This could not be saved. Check your connection and try again.',
    ),
  );

  @override
  Future<Result<void>> deleteEducation(String candidateId, String id) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> upsertCertification(
    String candidateId,
    ExternalCertificationEntry entry,
  ) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteCertification(String candidateId, String id) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> upsertProject(String candidateId, ProjectEntry entry) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deleteProject(String candidateId, String id) =>
      throw UnimplementedError();
}
