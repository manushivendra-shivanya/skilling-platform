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

  group('jobSourceDisplayName', () {
    test('returns the human-readable name for a known aggregator source', () {
      expect(jobSourceDisplayName('adzuna'), 'Adzuna');
      expect(jobSourceDisplayName('jooble'), 'Jooble');
      expect(jobSourceDisplayName('careerjet'), 'Careerjet');
      expect(jobSourceDisplayName('greenhouse'), 'Employer careers page');
      expect(jobSourceDisplayName('lever'), 'Employer careers page');
    });

    test('is null for flora (Flora-native listings)', () {
      expect(jobSourceDisplayName('flora'), isNull);
    });

    test('is null for an unrecognised source', () {
      expect(jobSourceDisplayName('not-a-real-source'), isNull);
    });
  });

  group('jobSourceCaption', () {
    test('is null for flora, since it needs no provenance caption', () {
      expect(jobSourceCaption('flora'), isNull);
    });

    test('is "via {name}" for a known aggregator source', () {
      expect(jobSourceCaption('adzuna'), 'via Adzuna');
      expect(jobSourceCaption('jooble'), 'via Jooble');
    });

    test('is null for an unrecognised source', () {
      expect(jobSourceCaption('not-a-real-source'), isNull);
    });
  });
}
