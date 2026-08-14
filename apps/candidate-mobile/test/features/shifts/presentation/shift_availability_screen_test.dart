import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/widgets/app_sticky_footer.dart';
import 'package:candidate_mobile/features/shifts/domain/shift_availability.dart';
import 'package:candidate_mobile/features/shifts/presentation/shift_availability_screen.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prefills the form from the current saved availability', (
    tester,
  ) async {
    final repository = _FakeShiftAvailabilityRepository(
      const ShiftAvailability(
        availableToday: true,
        availableFrom: '16:00',
        availableUntil: '22:00',
        preferredCity: 'Bengaluru',
        maxTravelKm: 8,
        minPay: 500,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    // Field order matches the form: from, until, city, travel km, min pay.
    // Reading the controllers directly (rather than find.text) sidesteps
    // Material's floating-label hint text, which stays built (invisibly)
    // in the tree even once a field is non-empty and can share the same
    // literal value as this fixture's hints.
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller!.text, '16:00');
    expect(fields[1].controller!.text, '22:00');
    expect(fields[2].controller!.text, 'Bengaluru');
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
  });

  testWidgets('saving persists the edited fields and shows confirmation', (
    tester,
  ) async {
    final repository = _FakeShiftAvailabilityRepository(
      const ShiftAvailability(),
    );
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '18:00');
    await tester.enterText(find.byType(TextField).at(2), 'Pune');
    await tester.tap(find.text('Save availability'));
    await tester.pumpAndSettle();

    expect(find.text('Availability saved.'), findsOneWidget);
    expect(repository.saved, isNotNull);
    expect(repository.saved!.availableFrom, '18:00');
    expect(repository.saved!.preferredCity, 'Pune');
  });

  testWidgets('a save failure shows the error message instead', (tester) async {
    final repository = _FakeShiftAvailabilityRepository(
      const ShiftAvailability(),
      saveFails: true,
    );
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save availability'));
    await tester.pumpAndSettle();

    // Not the raw 'Could not save your availability.' internal message:
    // AppFailure's own `message` is English-only developer/log text -- the
    // screen shows a localized, generic message keyed off the failure's
    // type instead.
    expect(
      find.text('Something went wrong saving this on your device.'),
      findsOneWidget,
    );
  });

  testWidgets('a load failure shows the error state with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeShiftAvailabilityRepository(null, loadFails: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Availability could not be loaded'), findsOneWidget);
  });

  testWidgets(
    'the save button is pinned in a sticky footer below the scrolling form',
    (tester) async {
      final repository = _FakeShiftAvailabilityRepository(
        const ShiftAvailability(),
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppStickyFooter), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppStickyFooter),
          matching: find.text('Save availability'),
        ),
        findsOneWidget,
      );
    },
  );
}

Widget _app(ShiftAvailabilityRepository repository) =>
    UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'candidate-1',
                isAuthenticated: true,
              ),
            ),
          ),
          shiftAvailabilityRepositoryProvider.overrideWithValue(repository),
        ],
      ),
      child: MaterialApp(
        theme: buildAppTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ShiftAvailabilityScreen(),
      ),
    );

class _FakeShiftAvailabilityRepository implements ShiftAvailabilityRepository {
  _FakeShiftAvailabilityRepository(
    this._current, {
    this.saveFails = false,
    this.loadFails = false,
  });

  ShiftAvailability? _current;
  final bool saveFails;
  final bool loadFails;
  ShiftAvailability? saved;

  @override
  Future<Result<ShiftAvailability>> readAvailability(String candidateId) async {
    if (loadFails) {
      return const ResultFailure(
        StorageFailure('Availability could not be loaded.'),
      );
    }
    return Success(_current ?? const ShiftAvailability());
  }

  @override
  Future<Result<void>> saveAvailability(
    String candidateId,
    ShiftAvailability availability,
  ) async {
    if (saveFails) {
      return const ResultFailure(
        StorageFailure('Could not save your availability.'),
      );
    }
    saved = availability;
    _current = availability;
    return const Success(null);
  }
}
