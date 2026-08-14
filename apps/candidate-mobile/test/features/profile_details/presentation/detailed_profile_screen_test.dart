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
  // This screen renders five stacked sections -- taller than the default
  // 800x600 test surface. ListView only mounts elements within the
  // viewport (plus a small cache extent), so without this, find.text on
  // anything below Experience silently returns zero results instead of
  // scrolling into view.
  void enlargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
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
        home: const DetailedProfileScreen(),
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
      await tester.enterText(find.byType(TextField).last, 'forklift');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('forklift'), findsOneWidget);

      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      expect(repository.profile.phone, '9999999999');
      expect(repository.profile.skills, contains('forklift'));
    },
  );
}
