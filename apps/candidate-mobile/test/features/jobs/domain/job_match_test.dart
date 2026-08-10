import 'package:candidate_mobile/features/career_passport/domain/role_readiness.dart';
import 'package:candidate_mobile/features/jobs/domain/job_match.dart';
import 'package:candidate_mobile/features/jobs/domain/jobs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test('a job with no known signal still gets the flat baseline, not zero', () {
    final job = _job();

    final score = deriveJobMatch(
      job,
      readiness: const [],
      preferredCity: null,
      now: now,
    );

    expect(score, 5);
  });

  test('ready-level evidence in the job\'s mapped category adds 30', () {
    final job = _job(title: 'Warehouse Operations Associate');
    final readiness = [
      _summary(ReadinessCategory.receiving, ReadinessLevel.ready),
    ];

    final score = deriveJobMatch(
      job,
      readiness: readiness,
      preferredCity: null,
      now: now,
    );

    expect(score, 5 + 30);
  });

  test('developing-level evidence adds 18, needs-practice adds 8', () {
    final job = _job(title: 'Warehouse Operations Associate');

    final developing = deriveJobMatch(
      job,
      readiness: [
        _summary(ReadinessCategory.receiving, ReadinessLevel.developing),
      ],
      preferredCity: null,
      now: now,
    );
    final needsPractice = deriveJobMatch(
      job,
      readiness: [
        _summary(ReadinessCategory.receiving, ReadinessLevel.needsPractice),
      ],
      preferredCity: null,
      now: now,
    );

    expect(developing, 5 + 18);
    expect(needsPractice, 5 + 8);
  });

  test(
    'unknown-level evidence and a missing category summary both add nothing',
    () {
      final job = _job(title: 'Warehouse Operations Associate');

      final unknownLevel = deriveJobMatch(
        job,
        readiness: [
          _summary(ReadinessCategory.receiving, ReadinessLevel.unknown),
        ],
        preferredCity: null,
        now: now,
      );
      final noSummaryAtAll = deriveJobMatch(
        job,
        readiness: const [],
        preferredCity: null,
        now: now,
      );

      expect(unknownLevel, 5);
      expect(noSummaryAtAll, 5);
    },
  );

  test('a title with no clear role bucket gets no evidence-fit bonus', () {
    final job = _job(title: 'Business Development Manager');

    final score = deriveJobMatch(
      job,
      readiness: [_summary(ReadinessCategory.receiving, ReadinessLevel.ready)],
      preferredCity: null,
      now: now,
    );

    // isSupervisorRole is derived from the title keyword "manager", so this
    // maps to Supervisor, not Receiving -- the Receiving:ready summary
    // above must not apply.
    expect(score, 5);
  });

  test(
    'a supervisor-flagged job maps to Supervisor regardless of role-bucket keywords',
    () {
      final job = _job(title: 'Warehouse Supervisor');

      final score = deriveJobMatch(
        job,
        readiness: [
          _summary(ReadinessCategory.supervisor, ReadinessLevel.ready),
        ],
        preferredCity: null,
        now: now,
      );

      expect(score, 5 + 30);
    },
  );

  test(
    'a job in the candidate\'s preferred city adds 34, case-insensitively',
    () {
      final job = _job(location: 'Bhiwandi, Maharashtra');

      final score = deriveJobMatch(
        job,
        readiness: const [],
        preferredCity: 'BHIWANDI',
        now: now,
      );

      expect(score, 5 + 34);
    },
  );

  test(
    'a preferred city that does not appear in the location adds nothing',
    () {
      final job = _job(location: 'Pune, Maharashtra');

      final score = deriveJobMatch(
        job,
        readiness: const [],
        preferredCity: 'Bhiwandi',
        now: now,
      );

      expect(score, 5);
    },
  );

  test('a Flora-verified listing adds 9', () {
    final flora = deriveJobMatch(
      _job(source: 'flora'),
      readiness: const [],
      preferredCity: null,
      now: now,
    );
    final aggregator = deriveJobMatch(
      _job(source: 'adzuna'),
      readiness: const [],
      preferredCity: null,
      now: now,
    );

    expect(flora, 5 + 9);
    expect(aggregator, 5);
  });

  test('a listing posted within 14 days adds 5; older does not', () {
    final recent = deriveJobMatch(
      _job(publishedAt: now.subtract(const Duration(days: 5))),
      readiness: const [],
      preferredCity: null,
      now: now,
    );
    final stale = deriveJobMatch(
      _job(publishedAt: now.subtract(const Duration(days: 40))),
      readiness: const [],
      preferredCity: null,
      now: now,
    );
    final unknown = deriveJobMatch(
      _job(publishedAt: null),
      readiness: const [],
      preferredCity: null,
      now: now,
    );

    expect(recent, 5 + 5);
    expect(stale, 5);
    expect(unknown, 5);
  });

  test('every bonus stacks to a realistic ceiling below 99', () {
    final job = _job(
      title: 'Warehouse Operations Associate',
      location: 'Bhiwandi, Maharashtra',
      source: 'flora',
      publishedAt: now.subtract(const Duration(days: 1)),
    );

    final score = deriveJobMatch(
      job,
      readiness: [_summary(ReadinessCategory.receiving, ReadinessLevel.ready)],
      preferredCity: 'Bhiwandi',
      now: now,
    );

    expect(score, 5 + 30 + 34 + 9 + 5);
    expect(score, lessThan(99));
  });
}

JobOpportunity _job({
  String title = 'Inventory Executive',
  String location = 'Gurugram, Haryana',
  String source = 'adzuna',
  DateTime? publishedAt,
}) {
  return JobOpportunity(
    id: 'job-1',
    title: title,
    employer: 'Test Employer',
    location: location,
    isSupervisorRole: jobTitleLooksLikeSupervisorRole(title),
    description: 'A test job.',
    source: source,
    publishedAt: publishedAt,
  );
}

RoleReadinessSummary _summary(
  ReadinessCategory category,
  ReadinessLevel level,
) {
  return RoleReadinessSummary(
    category: category,
    level: level,
    averageScore: level == ReadinessLevel.unknown ? null : 70,
    evidenceCount: level == ReadinessLevel.unknown ? 0 : 1,
  );
}
