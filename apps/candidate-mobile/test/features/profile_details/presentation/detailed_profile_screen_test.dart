import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/profile_details/data/in_memory_detailed_profile_repository.dart';
import 'package:candidate_mobile/features/profile_details/domain/detailed_candidate_profile.dart';
import 'package:candidate_mobile/features/profile_details/presentation/detailed_profile_screen.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // This screen renders eight stacked sections -- taller than the default
  // 800x600 test surface. ListView only mounts elements within the
  // viewport (plus a small cache extent), so without this, find.text on
  // anything below Experience silently returns zero results instead of
  // scrolling into view.
  void enlargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrap(InMemoryDetailedProfileRepository repository) {
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
        detailedProfileRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DetailedProfileScreen(onImportFromResume: () {}),
      ),
    );
  }

  testWidgets('shows every section empty and 0% complete for a fresh profile', (
    tester,
  ) async {
    enlargeViewport(tester);
    await tester.pumpWidget(wrap(InMemoryDetailedProfileRepository()));
    await tester.pumpAndSettle();

    expect(find.text('0% complete'), findsOneWidget);
    expect(find.text('No experience added yet'), findsOneWidget);
    expect(find.text('No education added yet'), findsOneWidget);
    expect(find.text('No certifications added yet'), findsOneWidget);
    expect(find.text('No projects added yet'), findsOneWidget);
    expect(find.text('No skills added yet'), findsOneWidget);
    expect(find.text('No languages added yet.'), findsOneWidget);
  });

  testWidgets('adding a work-experience entry shows it in the list', (
    tester,
  ) async {
    enlargeViewport(tester);
    await tester.pumpWidget(wrap(InMemoryDetailedProfileRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add experience'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Warehouse Associate',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Company'),
      'Apex Logistics',
    );
    // Two "Save" buttons exist at once here: the bottom sheet's own, and
    // the (unrelated) Contact & Skills card's, still mounted underneath --
    // the sheet overlays rather than replaces the screen. It's added to
    // the tree after the screen, so .last is the sheet's.
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Warehouse Associate'), findsOneWidget);
    expect(find.text('Apex Logistics'), findsOneWidget);
    expect(find.text('No experience added yet'), findsNothing);
  });

  testWidgets('deleting a work-experience entry removes it after confirming', (
    tester,
  ) async {
    final repository = InMemoryDetailedProfileRepository(
      initialProfile: const DetailedCandidateProfile(
        phone: '',
        email: '',
        skills: [],
        workExperience: [
          WorkExperienceEntry(
            id: 'w1',
            title: 'Warehouse Associate',
            company: 'Apex Logistics',
          ),
        ],
        education: [],
        certifications: [],
        projects: [],
      ),
    );
    enlargeViewport(tester);
    await tester.pumpWidget(wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Warehouse Associate'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // Confirmation dialog -- "Delete" is the destructive confirm button.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Warehouse Associate'), findsNothing);
    expect(find.text('No experience added yet'), findsOneWidget);
  });

  testWidgets(
    'saving contact info and a skill persists through the repository',
    (tester) async {
      enlargeViewport(tester);
      final repository = InMemoryDetailedProfileRepository();
      await tester.pumpWidget(wrap(repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Phone'),
        '9999999999',
      );
      await tester.enterText(
        find.byKey(const ValueKey('detailed-profile-add-skill-field')),
        'forklift',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('forklift'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('detailed-profile-contact-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repository.profile.phone, '9999999999');
      expect(repository.profile.skills, contains('forklift'));
    },
  );

  testWidgets(
    'saving headline, total experience, and a summary persists through the repository',
    (tester) async {
      enlargeViewport(tester);
      final repository = InMemoryDetailedProfileRepository();
      await tester.pumpWidget(wrap(repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Headline'),
        'Warehouse Operations Associate',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Total experience'),
        '3 yrs 4 mos',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Summary'),
        'Reliable, WMS-certified associate.',
      );

      await tester.tap(
        find.byKey(const ValueKey('detailed-profile-about-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repository.profile.headline, 'Warehouse Operations Associate');
      expect(repository.profile.totalExperience, '3 yrs 4 mos');
      expect(repository.profile.summary, 'Reliable, WMS-certified associate.');
    },
  );

  testWidgets('adding a language shows it in the list', (tester) async {
    enlargeViewport(tester);
    final repository = InMemoryDetailedProfileRepository();
    await tester.pumpWidget(wrap(repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add language'));
    await tester.tap(find.text('Add language'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Language'), 'Hindi');
    await tester.tap(find.text('Native'));
    // Two "Save" buttons exist at once here: the bottom sheet's own, and
    // the (unrelated) always-visible cards' underneath -- same reasoning
    // as the work-experience test above, `.last` is the sheet's.
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('Native'), findsOneWidget);
    expect(find.text('No languages added yet.'), findsNothing);
    expect(repository.profile.languages, hasLength(1));
    expect(repository.profile.languages.single.language, 'Hindi');
    expect(
      repository.profile.languages.single.proficiency,
      LanguageProficiency.native,
    );
  });

  testWidgets('saving career preferences persists through the repository', (
    tester,
  ) async {
    enlargeViewport(tester);
    final repository = InMemoryDetailedProfileRepository();
    await tester.pumpWidget(wrap(repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Expected CTC (₹/yr)'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Expected CTC (₹/yr)'),
      '320000',
    );
    await tester.tap(find.text('1 month'));
    await tester.tap(find.text('Full-time'));
    await tester.tap(find.text('Willing to relocate'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('detailed-profile-career-preferences-save-button'),
      ),
    );
    await tester.pumpAndSettle();

    final saved = repository.profile.careerPreferences;
    expect(saved.expectedCtcAmount, 320000);
    expect(saved.noticePeriod, NoticePeriod.oneMonth);
    expect(saved.employmentTypes, {EmploymentType.fullTime});
    expect(saved.willingToRelocate, isTrue);
  });
}
