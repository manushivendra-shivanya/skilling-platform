import 'package:candidate_mobile/core/storage/local_key_value_store.dart';
import 'package:candidate_mobile/features/onboarding/data/local_onboarding_entry_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves and restores the selected language', () async {
    final repository = LocalOnboardingEntryRepository(
      InMemoryLocalKeyValueStore(),
    );

    expect(await repository.readSelectedLanguage(), isNull);

    await repository.saveSelectedLanguage(CandidateLanguage.hinglish);

    expect(await repository.readSelectedLanguage(), CandidateLanguage.hinglish);
  });

  test('ignores an unsupported stored language code', () async {
    final store = InMemoryLocalKeyValueStore();
    await store.write(
      LocalOnboardingEntryRepository.selectedLanguageKey,
      'unsupported',
    );

    final repository = LocalOnboardingEntryRepository(store);

    expect(await repository.readSelectedLanguage(), isNull);
  });
}
