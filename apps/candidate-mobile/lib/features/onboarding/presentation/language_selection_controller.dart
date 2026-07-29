import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../domain/candidate_language.dart';

final languageSelectionControllerProvider =
    AsyncNotifierProvider<LanguageSelectionController, CandidateLanguage?>(
      LanguageSelectionController.new,
    );

class LanguageSelectionController extends AsyncNotifier<CandidateLanguage?> {
  @override
  Future<CandidateLanguage?> build() {
    return ref.read(onboardingEntryRepositoryProvider).readSelectedLanguage();
  }

  Future<void> select(CandidateLanguage language) async {
    state = const AsyncLoading();

    try {
      await ref
          .read(onboardingEntryRepositoryProvider)
          .saveSelectedLanguage(language);
      state = AsyncData(language);
      unawaited(
        ref
            .read(analyticsTrackerProvider)
            .track(AnalyticsEvent.languageSelected(language.code)),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void retry() {
    ref.invalidateSelf();
  }
}
