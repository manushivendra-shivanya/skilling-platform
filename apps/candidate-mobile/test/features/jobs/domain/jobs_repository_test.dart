import 'package:candidate_mobile/features/jobs/domain/jobs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jobTitleLooksLikeSupervisorRole', () {
    test('matches titles containing supervisor, lead or manager', () {
      expect(jobTitleLooksLikeSupervisorRole('Shift Supervisor'), isTrue);
      expect(jobTitleLooksLikeSupervisorRole('Warehouse Team Lead'), isTrue);
      expect(jobTitleLooksLikeSupervisorRole('Inventory Manager'), isTrue);
    });

    test('is case-insensitive', () {
      expect(jobTitleLooksLikeSupervisorRole('SHIFT SUPERVISOR'), isTrue);
    });

    test('does not match an individual-contributor title', () {
      expect(
        jobTitleLooksLikeSupervisorRole('Warehouse Operations Associate'),
        isFalse,
      );
      expect(jobTitleLooksLikeSupervisorRole('Inventory Executive'), isFalse);
    });
  });
}
