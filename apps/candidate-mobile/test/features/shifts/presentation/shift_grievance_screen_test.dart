import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_colors.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/shifts/domain/shift_grievance.dart';
import 'package:candidate_mobile/features/shifts/presentation/shift_grievance_screen.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an empty state when there are no tickets yet', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeShiftGrievanceRepository([])));
    await tester.pumpAndSettle();

    expect(find.text('No tickets yet'), findsOneWidget);
  });

  testWidgets('lists past tickets with a truncated, uppercased reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeShiftGrievanceRepository([
          ShiftGrievance(
            id: 'abcdef1234567890',
            category: ShiftGrievanceCategory.payoutMismatch,
            description: 'Payout total looked short.',
            status: ShiftGrievanceStatus.open,
            resolutionNotes: null,
            createdAt: DateTime(2026, 8, 1),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#ABCDEF12'), findsOneWidget);
    expect(find.text('Payout mismatch'), findsOneWidget);
    expect(find.text('Payout total looked short.'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);

    // Category reads as a small muted caption, description as the main
    // body text -- distinct visual weights instead of three same-size
    // lines.
    final categoryStyle = tester
        .widget<Text>(find.text('Payout mismatch'))
        .style;
    final descriptionStyle = tester
        .widget<Text>(find.text('Payout total looked short.'))
        .style;
    expect(categoryStyle?.fontWeight, FontWeight.w700);
    expect(categoryStyle?.color, AppColors.inkMuted);
    expect(descriptionStyle?.color, isNot(AppColors.inkMuted));
  });

  testWidgets('submitting with no description shows a validation message', (
    tester,
  ) async {
    final repository = _FakeShiftGrievanceRepository([]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Describe what happened.'), findsOneWidget);
    expect(repository.submitted, isEmpty);
    expect(
      tester.widget<Text>(find.text('Describe what happened.')).style?.color,
      AppColors.error,
    );
  });

  testWidgets(
    'submitting a valid ticket clears the form and refreshes the list',
    (tester) async {
      final repository = _FakeShiftGrievanceRepository([]);
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'Supervisor asked me to skip a safety step.',
      );
      await tester.tap(find.text('Submit ticket'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket submitted.'), findsOneWidget);
      expect(repository.submitted, hasLength(1));
      expect(
        repository.submitted.single.description,
        'Supervisor asked me to skip a safety step.',
      );
      expect(find.text('Unsafe work'), findsNothing);
    },
  );

  testWidgets('a load failure shows the error state with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeShiftGrievanceRepository([], loadFails: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Support tickets could not be loaded'), findsOneWidget);
  });
}

Widget _app(ShiftGrievanceRepository repository) => UncontrolledProviderScope(
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
      shiftGrievanceRepositoryProvider.overrideWithValue(repository),
    ],
  ),
  child: MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ShiftGrievanceScreen(),
  ),
);

class _SubmittedGrievance {
  _SubmittedGrievance(this.category, this.description);
  final ShiftGrievanceCategory category;
  final String description;
}

class _FakeShiftGrievanceRepository implements ShiftGrievanceRepository {
  _FakeShiftGrievanceRepository(this._grievances, {this.loadFails = false});

  final List<ShiftGrievance> _grievances;
  final bool loadFails;
  final List<_SubmittedGrievance> submitted = [];

  @override
  Future<Result<List<ShiftGrievance>>> loadGrievances(
    String candidateId,
  ) async {
    if (loadFails) {
      return const ResultFailure(
        StorageFailure('Support tickets could not be loaded.'),
      );
    }
    return Success(_grievances);
  }

  @override
  Future<Result<void>> submitGrievance(
    String candidateId, {
    required ShiftGrievanceCategory category,
    required String description,
    String? shiftApplicationId,
  }) async {
    submitted.add(_SubmittedGrievance(category, description));
    return const Success(null);
  }
}
