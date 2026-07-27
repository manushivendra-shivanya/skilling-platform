import '../../../core/storage/local_key_value_store.dart';
import '../domain/candidate_language.dart';
import '../domain/onboarding_entry_repository.dart';

class LocalOnboardingEntryRepository implements OnboardingEntryRepository {
  LocalOnboardingEntryRepository(this._store);

  static const selectedLanguageKey = 'onboarding.selected_language';

  final LocalKeyValueStore _store;

  @override
  Future<CandidateLanguage?> readSelectedLanguage() async {
    final code = await _store.read(selectedLanguageKey);
    return CandidateLanguage.fromCode(code);
  }

  @override
  Future<void> saveSelectedLanguage(CandidateLanguage language) {
    return _store.write(selectedLanguageKey, language.code);
  }
}
