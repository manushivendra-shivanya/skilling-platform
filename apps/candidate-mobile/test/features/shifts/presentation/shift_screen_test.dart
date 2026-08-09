import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_repository.dart';
import 'package:candidate_mobile/features/shifts/domain/shifts_repository.dart';
import 'package:candidate_mobile/features/shifts/presentation/shift_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the Shift home list, the detail bottom sheet, and its two
/// branches (skill-gate vs. eligible-accept) -- the plan's "most important
/// MVP screen". `deriveShiftMatch`'s own rules are covered in isolation by
/// `shift_match_test.dart`.
void main() {
  testWidgets('shows shifts with match% and a demo-data caption', (
    tester,
  ) async {
    final container = _buildContainer(
      _FakeShiftsRepository([_eligibleShift, _gatedShift]),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('My Shift'), findsOneWidget);
    expect(
      find.text('Demo shifts • No live employer connection'),
      findsOneWidget,
    );
    expect(find.text('Best match', skipOffstage: false), findsOneWidget);
    expect(find.text('Starts soon', skipOffstage: false), findsOneWidget);
    expect(find.text('You match: 100%'), findsWidgets);
  });

  testWidgets('an empty catalogue shows the empty state', (tester) async {
    final container = _buildContainer(_FakeShiftsRepository(const []));
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('No shifts right now'), findsOneWidget);
  });

  testWidgets(
    'a shift requiring a competency the candidate lacks shows the skill-gate CTA, not Accept',
    (tester) async {
      final container = _buildContainer(_FakeShiftsRepository([_gatedShift]));
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Picker / Packer').first);
      await tester.pumpAndSettle();

      expect(find.text('Before accepting this shift'), findsOneWidget);
      expect(find.textContaining('Document Verification'), findsOneWidget);
      expect(find.text('Complete required skill'), findsOneWidget);
      expect(find.text('Accept shift'), findsNothing);
    },
  );

  testWidgets(
    'tapping the skill-gate CTA closes the sheet and calls onOpenSkillGap',
    (tester) async {
      final container = _buildContainer(_FakeShiftsRepository([_gatedShift]));
      addTearDown(container.dispose);
      var skillGapOpened = false;
      // The skill-gate CTA sits below the missing-competency copy in the
      // bottom sheet, past the default 800x600 test surface's fold.
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(container, onOpenSkillGap: () => skillGapOpened = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Picker / Packer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete required skill'));
      await tester.pumpAndSettle();

      expect(skillGapOpened, isTrue);
      expect(find.text('Before accepting this shift'), findsNothing);
    },
  );

  testWidgets(
    'an eligible shift shows Accept, and accepting updates the card status',
    (tester) async {
      final repository = _FakeShiftsRepository([_eligibleShift]);
      final container = _buildContainer(repository);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Picker / Packer').first);
      await tester.pumpAndSettle();

      expect(find.text('Accept shift'), findsOneWidget);
      await tester.tap(find.text('Accept shift'));
      await tester.pumpAndSettle();

      expect(find.text('Shift accepted.'), findsOneWidget);
      expect(repository.acceptedShiftIds, ['shift-eligible']);
      expect(find.text('Accepted'), findsWidgets);
    },
  );

  testWidgets('a failed accept shows the error and keeps the sheet open', (
    tester,
  ) async {
    final container = _buildContainer(
      _FakeShiftsRepository([_eligibleShift], acceptFails: true),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Picker / Packer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept shift'));
    await tester.pumpAndSettle();

    expect(find.text('This shift just filled up.'), findsOneWidget);
    expect(find.text('Accept shift'), findsOneWidget);
  });
}

final _eligibleShift = Shift(
  id: 'shift-eligible',
  roleTitle: 'Picker / Packer',
  siteName: 'Dark store',
  siteAddress: 'Andheri East',
  city: 'Mumbai',
  startsAt: DateTime(2026, 8, 10, 18),
  endsAt: DateTime(2026, 8, 10, 23),
  reportingTime: DateTime(2026, 8, 10, 18),
  headcount: 5,
  payAmount: 650,
  payCurrency: 'INR',
  requiredCompetencyIds: const [],
  description: 'Evening picking and packing.',
  supervisorName: 'Supervisor A',
  supervisorContact: null,
  cancellationPolicy: null,
);

final _gatedShift = Shift(
  id: 'shift-gated',
  roleTitle: 'Picker / Packer',
  siteName: 'Dark store',
  siteAddress: 'Andheri East',
  city: 'Mumbai',
  startsAt: DateTime(2026, 8, 11, 18),
  endsAt: DateTime(2026, 8, 11, 23),
  reportingTime: DateTime(2026, 8, 11, 18),
  headcount: 5,
  payAmount: 650,
  payCurrency: 'INR',
  requiredCompetencyIds: const ['document-verification'],
  description: 'Evening picking and packing.',
  supervisorName: 'Supervisor A',
  supervisorContact: null,
  cancellationPolicy: null,
);

ProviderContainer _buildContainer(ShiftsRepository repository) =>
    ProviderContainer(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'candidate-1',
              isAuthenticated: true,
            ),
          ),
        ),
        shiftsRepositoryProvider.overrideWithValue(repository),
        // Cascades to every Career Passport evidence source
        // ShiftsController.build() transitively awaits via
        // careerPassportControllerProvider.future -- without this, each
        // falls through to the real secure-storage platform channel, which
        // has no mock registered in the widget-test sandbox and hangs
        // forever (see pump_app.dart's identical rationale).
        secureKeyValueStoreProvider.overrideWithValue(
          InMemorySecureKeyValueStore(),
        ),
        // Also reachable via the same career passport chain -- the default
        // `AssetCertificationExamRepository`'s `rootBundle.loadString` was
        // observed to hang on its second call within one test process (see
        // pump_app.dart's identical override for the full rationale).
        certificationExamRepositoryProvider.overrideWithValue(
          const _NoExamCertificationExamRepository(),
        ),
      ],
    );

Widget _app(ProviderContainer container, {VoidCallback? onOpenSkillGap}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ShiftScreen(
            onOpenAvailability: () {},
            onOpenMyShifts: () {},
            onOpenPayouts: () {},
            onOpenGrievances: () {},
            onOpenSkillGap: onOpenSkillGap ?? () {},
          ),
        ),
      ),
    );

class _FakeShiftsRepository implements ShiftsRepository {
  _FakeShiftsRepository(this._shifts, {this.acceptFails = false});

  final List<Shift> _shifts;
  final bool acceptFails;
  final List<String> acceptedShiftIds = [];
  final List<ShiftApplication> _applications = [];

  @override
  bool get isLiveData => false;

  @override
  Future<Result<List<Shift>>> loadPublishedShifts() async => Success(_shifts);

  @override
  Future<Result<Shift>> loadShiftDetail(String shiftId) async =>
      Success(_shifts.firstWhere((s) => s.id == shiftId));

  @override
  Future<Result<List<ShiftApplication>>> loadMyApplications(
    String candidateId,
  ) async => Success(_applications);

  @override
  Future<Result<ShiftApplication>> acceptShift(
    String candidateId,
    String shiftId,
  ) async {
    if (acceptFails) {
      return const ResultFailure(
        ValidationFailure('This shift just filled up.'),
      );
    }
    acceptedShiftIds.add(shiftId);
    final application = ShiftApplication(
      id: 'app-$shiftId',
      shiftId: shiftId,
      status: ShiftApplicationStatus.accepted,
      checkedInAt: null,
      checkedOutAt: null,
      createdAt: DateTime(2026, 8, 9),
    );
    _applications.add(application);
    return Success(application);
  }

  @override
  Future<Result<ShiftApplication>> checkIn(
    String applicationId,
    String code,
  ) async => const ResultFailure(ValidationFailure('Not used in this test.'));

  @override
  Future<Result<ShiftApplication>> checkOut(String applicationId) async =>
      const ResultFailure(ValidationFailure('Not used in this test.'));
}

class _NoExamCertificationExamRepository
    implements CertificationExamRepository {
  const _NoExamCertificationExamRepository();

  @override
  Future<Result<CertificationExam>> loadExam() async => const ResultFailure(
    StorageFailure('No certification exam configured for this test.'),
  );
}
