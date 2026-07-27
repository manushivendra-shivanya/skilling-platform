import 'candidate_language.dart';

abstract interface class OnboardingEntryRepository {
  Future<CandidateLanguage?> readSelectedLanguage();

  Future<void> saveSelectedLanguage(CandidateLanguage language);
}
