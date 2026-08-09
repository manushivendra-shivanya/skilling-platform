import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/shifts_repository.dart';

class LocalMockShiftsRepository implements ShiftsRepository {
  LocalMockShiftsRepository(this._store);

  static const _applicationsKeyPrefix = 'candidate.mock_shift_applications.v1.';

  final SecureKeyValueStore _store;

  @override
  bool get isLiveData => false;

  @override
  Future<Result<List<Shift>>> loadPublishedShifts() async =>
      Success(_todayShifts());

  @override
  Future<Result<Shift>> loadShiftDetail(String shiftId) async {
    final shift = _todayShifts().where((s) => s.id == shiftId).firstOrNull;
    if (shift == null) {
      return const ResultFailure(
        ValidationFailure('This demo shift is not available.'),
      );
    }
    return Success(shift);
  }

  @override
  Future<Result<List<ShiftApplication>>> loadMyApplications(
    String candidateId,
  ) async {
    try {
      final encoded = await _store.read(_key(candidateId));
      if (encoded == null) return const Success([]);
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        throw const FormatException('Invalid shift application list');
      }
      return Success([
        for (final entry in decoded.cast<Map<String, Object?>>())
          _applicationFromJson(entry),
      ]);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your demo shift history could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ShiftApplication>> acceptShift(
    String candidateId,
    String shiftId,
  ) async {
    final current = await loadMyApplications(candidateId);
    return current.when(
      success: (existing) async {
        final already = existing.where((a) => a.shiftId == shiftId).firstOrNull;
        if (already != null) return Success(already);
        final application = ShiftApplication(
          id: 'demo-app-${DateTime.now().microsecondsSinceEpoch}',
          shiftId: shiftId,
          status: ShiftApplicationStatus.accepted,
          checkedInAt: null,
          checkedOutAt: null,
          createdAt: DateTime.now(),
        );
        return _persist(candidateId, [...existing, application]).then(
          (result) => result.when(
            success: (_) => Success(application),
            failure: ResultFailure.new,
          ),
        );
      },
      failure: (failure) async => ResultFailure(failure),
    );
  }

  @override
  Future<Result<ShiftApplication>> checkIn(
    String applicationId,
    String code,
  ) async {
    return const ResultFailure(
      ValidationFailure('Check-in is only available with a live connection.'),
    );
  }

  @override
  Future<Result<ShiftApplication>> checkOut(String applicationId) async {
    return const ResultFailure(
      ValidationFailure('Check-out is only available with a live connection.'),
    );
  }

  List<Shift> _todayShifts() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 18);
    final end = DateTime(now.year, now.month, now.day, 23);
    return [
      Shift(
        id: 'demo-picker-andheri',
        roleTitle: 'Picker / Packer',
        siteName: 'Dark store (Demo)',
        siteAddress: 'Andheri East',
        city: 'Mumbai',
        startsAt: start,
        endsAt: end,
        reportingTime: start,
        headcount: 5,
        payAmount: 650,
        payCurrency: 'INR',
        requiredCompetencyIds: const [],
        description:
            'Demo shift. Evening picking and packing at a simulated dark store.',
        supervisorName: 'Demo Supervisor',
        supervisorContact: null,
        cancellationPolicy: 'Demo data -- no real cancellation policy applies.',
      ),
    ];
  }

  Future<Result<void>> _persist(
    String candidateId,
    List<ShiftApplication> applications,
  ) async {
    try {
      await _store.write(
        _key(candidateId),
        jsonEncode([for (final a in applications) _applicationToJson(a)]),
      );
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'The demo shift could not be saved on this device.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Map<String, Object?> _applicationToJson(ShiftApplication application) => {
    'id': application.id,
    'shift_id': application.shiftId,
    'status': application.status.name,
    'checked_in_at': application.checkedInAt?.toIso8601String(),
    'checked_out_at': application.checkedOutAt?.toIso8601String(),
    'created_at': application.createdAt.toIso8601String(),
  };

  ShiftApplication _applicationFromJson(Map<String, Object?> json) =>
      ShiftApplication(
        id: json['id'] as String? ?? '',
        shiftId: json['shift_id'] as String? ?? '',
        status: ShiftApplicationStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => ShiftApplicationStatus.accepted,
        ),
        checkedInAt: (json['checked_in_at'] as String?) == null
            ? null
            : DateTime.parse(json['checked_in_at'] as String),
        checkedOutAt: (json['checked_out_at'] as String?) == null
            ? null
            : DateTime.parse(json['checked_out_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String _key(String candidateId) =>
      '$_applicationsKeyPrefix${candidateId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_')}';
}
