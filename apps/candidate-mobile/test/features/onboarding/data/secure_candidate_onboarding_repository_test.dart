import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'secure draft round trip preserves step, profile and consent versions',
    () async {
      final store = InMemorySecureKeyValueStore();
      final repository = SecureCandidateOnboardingRepository(store);
      final acceptedAt = DateTime.utc(2026, 7, 27, 12);
      final draft = CandidateOnboardingDraft(
        currentStep: 9,
        goal: CandidateGoal.findJob,
        fullName: 'Asha Kumari',
        city: 'Lucknow',
        state: 'Uttar Pradesh',
        pinCode: '226001',
        education: EducationLevel.twelfthPass,
        experience: ExperienceLevel.fresher,
        preferredRoles: const {
          LogisticsRole.warehouseAssociate,
          LogisticsRole.inventoryExecutive,
        },
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
      );

      final saveResult = await repository.saveDraft('candidate-one', draft);
      expect(
        saveResult.when(success: (_) => true, failure: (_) => false),
        isTrue,
      );

      final restored = (await repository.readDraft(
        'candidate-one',
      )).when(success: (value) => value, failure: (failure) => throw failure);
      expect(restored.currentStep, 9);
      expect(restored.fullName, 'Asha Kumari');
      expect(
        restored.preferredRoles,
        contains(LogisticsRole.inventoryExecutive),
      );
      expect(restored.hasCurrentRequiredConsents, isTrue);
      expect(
        restored.consents[OnboardingConsentVersions.termsPurpose]?.acceptedAt,
        acceptedAt,
      );
    },
  );

  test('drafts are isolated by candidate identity', () async {
    final repository = SecureCandidateOnboardingRepository(
      InMemorySecureKeyValueStore(),
    );
    await repository.saveDraft(
      'candidate-one',
      const CandidateOnboardingDraft(fullName: 'Candidate One'),
    );

    final secondDraft = (await repository.readDraft(
      'candidate-two',
    )).when(success: (value) => value, failure: (failure) => throw failure);
    expect(secondDraft.fullName, isEmpty);
  });
}
