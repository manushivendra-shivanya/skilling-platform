import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/domain/candidate_language.dart';
import '../../features/onboarding/presentation/language_selection_controller.dart';

/// Resolves the app's [Locale] -- what every `AppLocalizations.of(context)`
/// call in the app reads -- from the same persisted preference the
/// pre-onboarding language-selection screen already writes to
/// (`languageSelectionControllerProvider`), rather than a second, parallel
/// "app locale" setting a candidate would have to configure twice.
///
/// All three [CandidateLanguage] values are real, distinct ARB locales:
/// English and Hindi as ordinary `en`/`hi` ARB files, and Hinglish as
/// `Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn')` -- the
/// correct BCP-47 shape for "Hindi, written in Latin script" (ISO 15924's
/// `Latn` script subtag), which `flutter gen-l10n` supports as a first-class
/// locale variant the same way it supports e.g. `zh_Hans`/`zh_Hant`. See
/// `lib/l10n/app_hi_Latn.arb`.
final appLocaleProvider = Provider<Locale>((ref) {
  final language = ref.watch(languageSelectionControllerProvider).valueOrNull;
  return switch (language) {
    CandidateLanguage.hindi => const Locale('hi'),
    CandidateLanguage.hinglish => const Locale.fromSubtags(
      languageCode: 'hi',
      scriptCode: 'Latn',
    ),
    CandidateLanguage.english || null => const Locale('en'),
  };
});
