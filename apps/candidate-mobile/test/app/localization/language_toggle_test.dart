import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/home/data/mock_home_dashboard_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// End-to-end proof that the language chip is a real, working toggle --
/// not the "static हिं · EN label wired to nothing" it used to be. Home is
/// the natural place to exercise this: it's the chip's own host, and it
/// has visible text in both scripts (the Hindi/English-mixed default
/// before this feature existed, now pure per-locale).
void main() {
  testWidgets(
    'switching to Hindi from Home\'s language chip re-renders Home in Hindi',
    (tester) async {
      await tester.pumpCandidateApp(
        candidateSessionRepository: InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'dev-candidate-lang',
            isAuthenticated: true,
          ),
        ),
        candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(
          initialDraft: _completedDraft(),
        ),
        homeDashboardRepository: MockHomeDashboardRepository(
          response: Success(MockHomeDashboardRepository.sampleDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      // Defaults to English: no language has been picked yet.
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('नमस्ते'), findsNothing);

      await tester.tap(find.text('EN · हिं'));
      await tester.pumpAndSettle();

      expect(find.text('Choose your language'), findsOneWidget);
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();

      // The whole app rebuilt under the new Locale in the same run -- no
      // restart, no re-pump of a fresh widget tree.
      expect(find.text('नमस्ते'), findsOneWidget);
      expect(find.text('शुरू करें'), findsOneWidget);
      expect(find.text('Hello'), findsNothing);
      expect(find.text('हिं · EN'), findsOneWidget);
    },
  );
}

CandidateOnboardingDraft _completedDraft() {
  final acceptedAt = DateTime.utc(2026, 7, 27);
  return CandidateOnboardingDraft(
    currentStep: 10,
    goal: CandidateGoal.findJob,
    fullName: 'Rahul',
    city: 'Ghaziabad',
    state: 'Uttar Pradesh',
    pinCode: '201001',
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
