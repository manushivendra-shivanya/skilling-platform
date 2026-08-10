import 'package:candidate_mobile/features/jobs/domain/jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/presentation/job_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  group('jobCity', () {
    test('takes the segment before the first comma, trimmed', () {
      expect(jobCity('Bhiwandi, Maharashtra'), 'Bhiwandi');
    });

    test('falls back to the whole string when there is no comma', () {
      expect(jobCity('India'), 'India');
    });
  });

  group('JobFilters.activeCount / isEmpty', () {
    test('an untouched JobFilters.empty has zero active filters', () {
      expect(JobFilters.empty.activeCount, 0);
      expect(JobFilters.empty.isEmpty, isTrue);
    });

    test(
      'counts every populated dimension, datePosted included only when not any',
      () {
        final filters = JobFilters(
          locations: {'Bhiwandi'},
          roles: {'warehouse', 'dispatch'},
          companies: {'Apex Consumer Products'},
          datePosted: DatePostedFilter.pastWeek,
        );

        expect(filters.activeCount, 5);
        expect(filters.isEmpty, isFalse);
      },
    );
  });

  group('JobFilters.matches', () {
    test('an empty JobFilters matches every job', () {
      expect(JobFilters.empty.matches(_job(), now: now), isTrue);
    });

    test('a location filter matches only that city', () {
      const filters = JobFilters(locations: {'Bhiwandi'});

      expect(
        filters.matches(_job(location: 'Bhiwandi, Maharashtra'), now: now),
        isTrue,
      );
      expect(
        filters.matches(_job(location: 'Pune, Maharashtra'), now: now),
        isFalse,
      );
    });

    test('a role filter matches the title-derived bucket', () {
      const filters = JobFilters(roles: {'dispatch'});

      expect(
        filters.matches(_job(title: 'Dispatch Executive'), now: now),
        isTrue,
      );
      expect(
        filters.matches(
          _job(title: 'Warehouse Operations Associate'),
          now: now,
        ),
        isFalse,
      );
    });

    test(
      'the "supervisor" role filter matches isSupervisorRole, not a title bucket',
      () {
        const filters = JobFilters(roles: {'supervisor'});

        expect(
          filters.matches(_job(title: 'Warehouse Supervisor'), now: now),
          isTrue,
        );
        expect(
          filters.matches(
            _job(title: 'Warehouse Operations Associate'),
            now: now,
          ),
          isFalse,
        );
      },
    );

    test('a company filter matches the exact employer name', () {
      const filters = JobFilters(companies: {'Apex Consumer Products'});

      expect(
        filters.matches(_job(employer: 'Apex Consumer Products'), now: now),
        isTrue,
      );
      expect(
        filters.matches(_job(employer: 'Northstar Freight'), now: now),
        isFalse,
      );
    });

    test(
      'past-week excludes anything older than 7 days, including unknown-date jobs',
      () {
        const filters = JobFilters(datePosted: DatePostedFilter.pastWeek);

        expect(
          filters.matches(
            _job(publishedAt: now.subtract(const Duration(days: 3))),
            now: now,
          ),
          isTrue,
        );
        expect(
          filters.matches(
            _job(publishedAt: now.subtract(const Duration(days: 10))),
            now: now,
          ),
          isFalse,
        );
        expect(filters.matches(_job(publishedAt: null), now: now), isFalse);
      },
    );

    test('past-month excludes anything older than 30 days', () {
      const filters = JobFilters(datePosted: DatePostedFilter.pastMonth);

      expect(
        filters.matches(
          _job(publishedAt: now.subtract(const Duration(days: 25))),
          now: now,
        ),
        isTrue,
      );
      expect(
        filters.matches(
          _job(publishedAt: now.subtract(const Duration(days: 40))),
          now: now,
        ),
        isFalse,
      );
    });

    test('multiple dimensions combine with AND', () {
      final filters = JobFilters(locations: {'Bhiwandi'}, roles: {'warehouse'});

      expect(
        filters.matches(
          _job(
            title: 'Warehouse Operations Associate',
            location: 'Bhiwandi, Maharashtra',
          ),
          now: now,
        ),
        isTrue,
      );
      expect(
        filters.matches(
          _job(title: 'Dispatch Executive', location: 'Bhiwandi, Maharashtra'),
          now: now,
        ),
        isFalse,
        reason: 'location matches but role does not',
      );
    });
  });

  test('copyWith replaces only the given dimensions', () {
    const original = JobFilters(locations: {'Bhiwandi'}, roles: {'warehouse'});

    final updated = original.copyWith(roles: {'dispatch'});

    expect(updated.locations, {'Bhiwandi'});
    expect(updated.roles, {'dispatch'});
  });
}

JobOpportunity _job({
  String title = 'Inventory Executive',
  String employer = 'Test Employer',
  String location = 'Gurugram, Haryana',
  DateTime? publishedAt,
}) {
  return JobOpportunity(
    id: 'job-1',
    title: title,
    employer: employer,
    location: location,
    isSupervisorRole: jobTitleLooksLikeSupervisorRole(title),
    description: 'A test job.',
    source: 'flora',
    publishedAt: publishedAt,
  );
}
