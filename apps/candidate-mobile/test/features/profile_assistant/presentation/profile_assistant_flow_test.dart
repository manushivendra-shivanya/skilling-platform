import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/profile_assistant/domain/profile_assistant_repository.dart';
import 'package:candidate_mobile/features/profile_assistant/domain/profile_gap.dart';
import 'package:candidate_mobile/features/profile_assistant/presentation/profile_assistant_screen.dart';
import 'package:candidate_mobile/features/profile_assistant/presentation/profile_completion_screen.dart';
import 'package:candidate_mobile/features/profile_details/data/in_memory_detailed_profile_repository.dart';
import 'package:candidate_mobile/features/profile_details/domain/detailed_candidate_profile.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a scripted reply per turn, so a whole conversation can be
/// driven deterministically without a live model.
class _ScriptedAssistantRepository implements ProfileAssistantRepository {
  _ScriptedAssistantRepository(this._replies);

  final List<AssistantReply> _replies;
  final requests = <AssistantTurnRequest>[];
  int _index = 0;

  @override
  Future<Result<AssistantReply>> continueConversation(
    AssistantTurnRequest request,
  ) async {
    requests.add(request);
    final reply = _replies[_index.clamp(0, _replies.length - 1)];
    _index += 1;
    return Success(reply);
  }
}

class _FailingAssistantRepository implements ProfileAssistantRepository {
  @override
  Future<Result<AssistantReply>> continueConversation(
    AssistantTurnRequest request,
  ) async => const ResultFailure(NetworkFailure('No connection.'));
}

void main() {
  void enlargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrap({
    required Widget home,
    required InMemoryDetailedProfileRepository profile,
    ProfileAssistantRepository? assistant,
  }) {
    return ProviderScope(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'candidate-1',
              isAuthenticated: true,
            ),
          ),
        ),
        detailedProfileRepositoryProvider.overrideWithValue(profile),
        candidateOnboardingRepositoryProvider.overrideWithValue(
          InMemoryCandidateOnboardingRepository(),
        ),
        if (assistant != null)
          profileAssistantRepositoryProvider.overrideWithValue(assistant),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  testWidgets(
    'the completion screen names what is missing, top filters first',
    (tester) async {
      enlargeViewport(tester);
      await tester.pumpWidget(
        wrap(
          profile: InMemoryDetailedProfileRepository(),
          home: ProfileCompletionScreen(
            onOpenAssistant: () {},
            onFillManually: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your profile is 0% complete'), findsOneWidget);
      expect(find.text('How soon you can join'), findsOneWidget);
      expect(find.text('Expected salary'), findsOneWidget);
      // Both recruiter-filter gaps carry the tag; nothing else does.
      expect(find.text('Top filter'), findsNWidgets(2));
    },
  );

  testWidgets('a complete profile is told so, with nothing left to fix', (
    tester,
  ) async {
    enlargeViewport(tester);
    final profile = InMemoryDetailedProfileRepository(
      initialProfile: DetailedCandidateProfile.empty.copyWith(
        phone: '9876543210',
        email: 'asha@example.com',
        skills: const ['Forklift'],
        headline: 'Warehouse Associate',
        summary: 'Reliable.',
        totalExperience: '3 yrs',
        languages: const [
          LanguageEntry(
            id: 'l1',
            language: 'Hindi',
            proficiency: LanguageProficiency.native,
          ),
        ],
        workExperience: const [
          WorkExperienceEntry(id: 'w1', title: 'Associate', company: 'ABC'),
        ],
        education: const [EducationEntry(id: 'e1', institution: 'ITI')],
        careerPreferences: const CareerPreferences(
          noticePeriod: NoticePeriod.fifteenDays,
          expectedCtcAmount: 320000,
          preferredLocations: ['Lucknow'],
        ),
      ),
    );

    await tester.pumpWidget(
      wrap(
        profile: profile,
        home: ProfileCompletionScreen(
          onOpenAssistant: () {},
          onFillManually: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your profile is 100% complete'), findsOneWidget);
    expect(
      find.text('Nothing is missing. Your profile is ready for employers.'),
      findsOneWidget,
    );
    expect(find.text('Top filter'), findsNothing);
  });

  testWidgets(
    'the assistant opens with a question and saves the answer it extracts',
    (tester) async {
      enlargeViewport(tester);
      final profile = InMemoryDetailedProfileRepository();
      final assistant = _ScriptedAssistantRepository([
        const AssistantReply(
          text: 'Namaste! Aap kitne din mein join kar sakti hain?',
          updates: [],
          isComplete: false,
        ),
        const AssistantReply(
          text: 'Theek hai! Ab expected salary batayein?',
          updates: [
            AssistantFieldUpdate(
              field: ProfileGapId.noticePeriod,
              confirmation: '15 days set kar diya',
              noticePeriod: NoticePeriod.fifteenDays,
            ),
          ],
          isComplete: false,
        ),
      ]);

      await tester.pumpWidget(
        wrap(
          profile: profile,
          assistant: assistant,
          home: ProfileAssistantScreen(onDone: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Opening turn is the assistant's -- the candidate never faces an
      // empty box wondering what to type.
      expect(
        find.text('Namaste! Aap kitne din mein join kar sakti hain?'),
        findsOneWidget,
      );
      // It was told what is still missing, so it can ask about it.
      expect(
        assistant.requests.first.remainingFields,
        contains(ProfileGapId.noticePeriod),
      );

      await tester.enterText(
        find.byKey(const ValueKey('profile-assistant-composer')),
        'Pandrah din chahiye',
      );
      await tester.tap(find.byKey(const ValueKey('profile-assistant-send')));
      await tester.pumpAndSettle();

      expect(find.text('Pandrah din chahiye'), findsOneWidget);
      expect(
        find.text('Theek hai! Ab expected salary batayein?'),
        findsOneWidget,
      );
      // The answer really landed on the profile, and the candidate is
      // shown that it did rather than taking the model's word for it.
      expect(
        profile.profile.careerPreferences.noticePeriod,
        NoticePeriod.fifteenDays,
      );
      expect(find.textContaining('Saved'), findsOneWidget);
      // The second turn's history carries both prior messages.
      expect(assistant.requests.last.history, hasLength(2));
    },
  );

  testWidgets('a completed conversation swaps the composer for Done', (
    tester,
  ) async {
    enlargeViewport(tester);
    final assistant = _ScriptedAssistantRepository([
      const AssistantReply(
        text: 'Sab ho gaya. Dhanyavaad!',
        updates: [],
        isComplete: true,
      ),
    ]);

    await tester.pumpWidget(
      wrap(
        profile: InMemoryDetailedProfileRepository(),
        assistant: assistant,
        home: ProfileAssistantScreen(onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sab ho gaya. Dhanyavaad!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-assistant-done-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-assistant-composer')),
      findsNothing,
    );
  });

  testWidgets('a failed turn surfaces the failure instead of a blank screen', (
    tester,
  ) async {
    enlargeViewport(tester);

    await tester.pumpWidget(
      wrap(
        profile: InMemoryDetailedProfileRepository(),
        assistant: _FailingAssistantRepository(),
        home: ProfileAssistantScreen(onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // AppFailure renders its localized, type-based message (see
    // app_failure_localization.dart), not the raw string the repository
    // constructed it with.
    expect(
      find.text('No internet connection. Check your network and try again.'),
      findsOneWidget,
    );
    // Still usable -- the composer stays so a retry is one tap away.
    expect(
      find.byKey(const ValueKey('profile-assistant-composer')),
      findsOneWidget,
    );
  });
}
