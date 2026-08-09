import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/shifts/data/local_mock_shifts_repository.dart';
import 'package:candidate_mobile/features/shifts/domain/shifts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalMockShiftsRepository repository;

  setUp(() {
    repository = LocalMockShiftsRepository(InMemorySecureKeyValueStore());
  });

  test('is not live data', () {
    expect(repository.isLiveData, isFalse);
  });

  test('loadPublishedShifts returns the one demo shift', () async {
    final result = await repository.loadPublishedShifts();

    final shifts = result.when(success: (value) => value, failure: (_) => null);
    expect(shifts, isNotNull);
    expect(shifts, hasLength(1));
    expect(shifts!.single.id, 'demo-picker-andheri');
  });

  test('loadShiftDetail finds the demo shift by id', () async {
    final result = await repository.loadShiftDetail('demo-picker-andheri');

    expect(
      result.when(success: (value) => value.roleTitle, failure: (_) => null),
      'Picker / Packer',
    );
  });

  test('loadShiftDetail fails for an unknown shift id', () async {
    final result = await repository.loadShiftDetail('not-a-real-shift');

    expect(result, isA<ResultFailure<Shift>>());
  });

  test(
    'loadMyApplications starts empty for a candidate with no history',
    () async {
      final result = await repository.loadMyApplications('candidate-1');

      expect(
        result.when(success: (value) => value, failure: (_) => null),
        isEmpty,
      );
    },
  );

  test('acceptShift persists a new accepted application', () async {
    final result = await repository.acceptShift(
      'candidate-1',
      'demo-picker-andheri',
    );

    final application = result.when(
      success: (value) => value,
      failure: (_) => null,
    );
    expect(application, isNotNull);
    expect(application!.shiftId, 'demo-picker-andheri');
    expect(application.status, ShiftApplicationStatus.accepted);

    final reloaded = await repository.loadMyApplications('candidate-1');
    expect(
      reloaded.when(success: (value) => value, failure: (_) => null),
      hasLength(1),
    );
  });

  test('acceptShift is idempotent for the same candidate and shift', () async {
    final first = await repository.acceptShift(
      'candidate-1',
      'demo-picker-andheri',
    );
    final second = await repository.acceptShift(
      'candidate-1',
      'demo-picker-andheri',
    );

    final firstId = first.when(success: (v) => v.id, failure: (_) => null);
    final secondId = second.when(success: (v) => v.id, failure: (_) => null);
    expect(firstId, secondId);

    final all = await repository.loadMyApplications('candidate-1');
    expect(
      all.when(success: (value) => value, failure: (_) => null),
      hasLength(1),
    );
  });

  test('applications are scoped per candidate', () async {
    await repository.acceptShift('candidate-1', 'demo-picker-andheri');

    final other = await repository.loadMyApplications('candidate-2');

    expect(
      other.when(success: (value) => value, failure: (_) => null),
      isEmpty,
    );
  });

  test('checkIn is unavailable in the demo repository', () async {
    final result = await repository.checkIn('demo-app-1', '123456');

    expect(result, isA<ResultFailure<ShiftApplication>>());
  });

  test('checkOut is unavailable in the demo repository', () async {
    final result = await repository.checkOut('demo-app-1');

    expect(result, isA<ResultFailure<ShiftApplication>>());
  });
}
