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
/// [CandidateLanguage] has three values (English, Hindi, Hinglish) because
/// that is what the onboarding sign-in flow's own hand-written copy
/// (`SignInCopy.forLanguage`) supports. The ARB-based app-wide toggle this
/// provider drives only ships two real locales, `en` and `hi` -- there is no
/// Hinglish ARB file, and building one (Latin-script Hindi is not a locale
/// most tooling or translators recognise) is out of scope for this pass.
/// [CandidateLanguage.hinglish] and "no preference yet" both resolve to
/// English here; onboarding's own screens are unaffected and keep reading
/// [CandidateLanguage] directly for their three-way copy.
final appLocaleProvider = Provider<Locale>((ref) {
  final language = ref.watch(languageSelectionControllerProvider).valueOrNull;
  return switch (language) {
    CandidateLanguage.hindi => const Locale('hi'),
    CandidateLanguage.english ||
    CandidateLanguage.hinglish ||
    null => const Locale('en'),
  };
});
