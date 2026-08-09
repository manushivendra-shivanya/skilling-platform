import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_repository.dart';
import 'package:candidate_mobile/features/shifts/domain/shifts_repository.dart';
import 'package:candidate_mobile/features/shifts/presentation/my_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an empty state when nothing has been accepted', (
    tester,
  ) async {
    final container = _buildContainer(_FakeShiftsRepository());
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('No shifts yet'), findsOneWidget);
  });

  testWidgets(
    'an accepted application shows the check-in field, and requires a code',
    (tester) async {
      final repository = _FakeShiftsRepository(
        applications: [_acceptedApplication],
      );
      final container = _buildContainer(repository);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      expect(find.text('Check in'), findsOneWidget);
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the check-in code.'), findsOneWidget);
      expect(repository.checkInCalls, isEmpty);
    },
  );

  testWidgets('a correct check-in code moves the shift to Checked in', (
    tester,
  ) async {
    final repository = _FakeShiftsRepository(
      applications: [_acceptedApplication],
    );
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();

    expect(find.text('Checked in.'), findsOneWidget);
    expect(repository.checkInCalls, [('app-1', '123456')]);
    expect(find.text('Check out'), findsOneWidget);
  });

  testWidgets('a wrong check-in code shows the failure and stays accepted', (
    tester,
  ) async {
    final repository = _FakeShiftsRepository(
      applications: [_acceptedApplication],
      checkInFails: true,
    );
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();

    expect(find.text('That code did not match.'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
  });

  testWidgets('checking out a checked-in shift moves it to Completed', (
    tester,
  ) async {
    final repository = _FakeShiftsRepository(
      applications: [_checkedInApplication],
    );
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check out'));
    await tester.pumpAndSettle();

    expect(
      find.text('Checked out. Your payout is now pending approval.'),
      findsOneWidget,
    );
    expect(repository.checkOutCalls, ['app-1']);
    expect(
      find.text('Shift completed. Payout status is available under Payouts.'),
      findsOneWidget,
    );
  });
}

final _acceptedApplication = ShiftApplication(
  id: 'app-1',
  shiftId: 'shift-1',
  status: ShiftApplicationStatus.accepted,
  checkedInAt: null,
  checkedOutAt: null,
  createdAt: DateTime(2026, 8, 9),
);

final _checkedInApplication = ShiftApplication(
  id: 'app-1',
  shiftId: 'shift-1',
  status: ShiftApplicationStatus.checkedIn,
  checkedInAt: DateTime(2026, 8, 9, 18),
  checkedOutAt: null,
  createdAt: DateTime(2026, 8, 9),
);

final _shift = Shift(
  id: 'shift-1',
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
  description: null,
  supervisorName: null,
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
        secureKeyValueStoreProvider.overrideWithValue(
          InMemorySecureKeyValueStore(),
        ),
        certificationExamRepositoryProvider.overrideWithValue(
          const _NoExamCertificationExamRepository(),
        ),
      ],
    );

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(theme: buildAppTheme(), home: const MyShiftsScreen()),
);

class _FakeShiftsRepository implements ShiftsRepository {
  _FakeShiftsRepository({
    List<ShiftApplication> applications = const [],
    this.checkInFails = false,
  }) : _applications = List.of(applications);

  final List<ShiftApplication> _applications;
  final bool checkInFails;
  final List<(String, String)> checkInCalls = [];
  final List<String> checkOutCalls = [];

  @override
  bool get isLiveData => true;

  @override
  Future<Result<List<Shift>>> loadPublishedShifts() async => Success([_shift]);

  @override
  Future<Result<Shift>> loadShiftDetail(String shiftId) async =>
      Success(_shift);

  @override
  Future<Result<List<ShiftApplication>>> loadMyApplications(
    String candidateId,
  ) async => Success(_applications);

  @override
  Future<Result<ShiftApplication>> acceptShift(
    String candidateId,
    String shiftId,
  ) async => throw UnimplementedError('Not used in this test.');

  @override
  Future<Result<ShiftApplication>> checkIn(
    String applicationId,
    String code,
  ) async {
    checkInCalls.add((applicationId, code));
    if (checkInFails) {
      return const ResultFailure(ValidationFailure('That code did not match.'));
    }
    final updated = ShiftApplication(
      id: applicationId,
      shiftId: _applications.first.shiftId,
      status: ShiftApplicationStatus.checkedIn,
      checkedInAt: DateTime(2026, 8, 9, 18),
      checkedOutAt: null,
      createdAt: _applications.first.createdAt,
    );
    _applications
      ..clear()
      ..add(updated);
    return Success(updated);
  }

  @override
  Future<Result<ShiftApplication>> checkOut(String applicationId) async {
    checkOutCalls.add(applicationId);
    final updated = ShiftApplication(
      id: applicationId,
      shiftId: _applications.first.shiftId,
      status: ShiftApplicationStatus.completed,
      checkedInAt: _applications.first.checkedInAt,
      checkedOutAt: DateTime(2026, 8, 9, 23),
      createdAt: _applications.first.createdAt,
    );
    _applications
      ..clear()
      ..add(updated);
    return Success(updated);
  }
}

class _NoExamCertificationExamRepository
    implements CertificationExamRepository {
  const _NoExamCertificationExamRepository();

  @override
  Future<Result<CertificationExam>> loadExam() async => const ResultFailure(
    StorageFailure('No certification exam configured for this test.'),
  );
}
