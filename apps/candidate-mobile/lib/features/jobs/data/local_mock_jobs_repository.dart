import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/jobs_repository.dart';

class LocalMockJobsRepository implements JobsRepository {
  LocalMockJobsRepository(this._store);

  static const _applicationKeyPrefix = 'candidate.mock_applications.v1.';

  final SecureKeyValueStore _store;

  @override
  Future<Result<List<JobOpportunity>>> loadJobs() async {
    return const Success([
      JobOpportunity(
        id: 'warehouse-lucknow',
        title: 'Warehouse Operations Associate',
        employer: 'NorthStar Logistics (Demo)',
        location: 'Lucknow',
        isSupervisorRole: false,
        matchReason:
            'Matches your interest in warehouse operations. This explanation is mock data.',
      ),
      JobOpportunity(
        id: 'inventory-noida',
        title: 'Inventory Executive',
        employer: 'SwiftCart Fulfilment (Demo)',
        location: 'Noida',
        isSupervisorRole: false,
        matchReason:
            'Inventory learning can support this role. No eligibility decision has been made.',
      ),
      JobOpportunity(
        id: 'shift-delhi',
        title: 'Shift Supervisor',
        employer: 'MetroHub Services (Demo)',
        location: 'Delhi NCR',
        isSupervisorRole: true,
        matchReason:
            'Shown as a progression option. Experience requirements are not verified in this demo.',
      ),
    ]);
  }

  @override
  Future<Result<Set<String>>> readAppliedJobIds(String candidateId) async {
    try {
      final encoded = await _store.read(_key(candidateId));
      if (encoded == null) return const Success({});
      final decoded = jsonDecode(encoded);
      if (decoded is! List<Object?>) {
        throw const FormatException('Invalid application list');
      }
      return Success(decoded.whereType<String>().toSet());
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your saved demo applications could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveApplication(String candidateId, String jobId) async {
    final current = await readAppliedJobIds(candidateId);
    return current.when(
      success: (ids) async {
        try {
          await _store.write(
            _key(candidateId),
            jsonEncode({...ids, jobId}.toList()),
          );
          return const Success(null);
        } catch (error, stackTrace) {
          return ResultFailure(
            StorageFailure(
              'The demo application could not be saved on this device.',
              cause: error,
              stackTrace: stackTrace,
            ),
          );
        }
      },
      failure: ResultFailure.new,
    );
  }

  String _key(String candidateId) =>
      '$_applicationKeyPrefix${candidateId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_')}';
}
