import '../../../core/errors/result.dart';

/// Everything Candidate Home renders, in the shape a single
/// `GET /home/dashboard` response should take.
///
/// Home is the first screen on a low-bandwidth connection, so it is modelled
/// as one aggregate rather than six calls. Each field below records the
/// backend source it should be served from, so swapping
/// `MockHomeDashboardRepository` for the real API is a data-source change
/// and not a redesign.
///
/// Backend readiness (see supabase/migrations):
/// - Five of the six fields are derivable from tables that already exist.
/// - [nextInterview] is the one genuine gap: `job_applications.status` is
///   limited to submitted/withdrawn/shortlisted/rejected, and carries no
///   scheduled time or location. It is nullable here so Home renders
///   correctly until that is modelled.
class HomeDashboard {
  const HomeDashboard({
    required this.candidateFirstName,
    required this.goalRoleName,
    required this.readinessProgress,
    required this.evidence,
    required this.learningProgress,
    required this.pendingSyncCount,
    this.todayMission,
    this.pathway,
    this.nextInterview,
  });

  /// `candidate_profiles.display_name`, first token only.
  final String candidateFirstName;

  /// `candidate_profiles.preferred_role_codes[0]` resolved through
  /// `role_profiles.name`.
  final String goalRoleName;

  /// Existing field. Derived from `competency_evidence` against
  /// `role_competency_requirements`.
  final double readinessProgress;

  /// `competency_evidence`, counted within a recency window. The index
  /// `competency_evidence_candidate_created_idx (candidate_id, created_at desc)`
  /// already supports exactly this query.
  final EvidenceSummary evidence;

  /// Existing field. `candidate_learning_state.completed_unit_ids` over the
  /// pathway's `learning_units`.
  final double learningProgress;

  /// Existing field. Locally queued simulation events not yet accepted.
  final int pendingSyncCount;

  /// Lowest-sequence `learning_units` row for the active pathway that is not
  /// in `candidate_learning_state.completed_unit_ids`. Null when the pathway
  /// is finished or none is assigned yet.
  final TodayMission? todayMission;

  /// `learning_pathways` joined to `learning_units`. Null before a pathway is
  /// assigned.
  final PathwayProgress? pathway;

  /// Not yet modelled in the schema — see the class doc. Null until it is.
  final UpcomingInterview? nextInterview;

  /// Coarse band shown beside the readiness figure. Deliberately three wide
  /// states rather than a precise number: the spec forbids presenting a score
  /// with more confidence than the evidence behind it supports.
  ReadinessBand get readinessBand {
    if (readinessProgress < 0.34) return ReadinessBand.starting;
    if (readinessProgress < 0.75) return ReadinessBand.building;
    return ReadinessBand.jobReady;
  }
}

enum ReadinessBand {
  starting('Starting out'),
  building('Building'),
  jobReady('Job ready');

  const ReadinessBand(this.label);

  final String label;
}

/// How much proof of competence the candidate has accumulated, and over what
/// window. The window travels with the count because a bare number invites
/// the reader to assume it is lifetime, and recency is what employers weigh.
class EvidenceSummary {
  const EvidenceSummary({required this.count, required this.windowDays});

  final int count;
  final int windowDays;
}

/// The single task Home asks the candidate to do today.
///
/// [durationMinutes] and the step position are part of the model, not
/// decoration: a candidate on a prepaid data plan decides whether to start
/// based on what it will cost them.
class TodayMission {
  const TodayMission({
    required this.unitId,
    required this.title,
    required this.summary,
    required this.durationMinutes,
    required this.stepNumber,
    required this.totalSteps,
  });

  /// `learning_units.id` — the deep link target, so the primary button starts
  /// the unit instead of pointing at another tab.
  final String unitId;

  /// `learning_units.title`.
  final String title;

  /// First line of `learning_units.content`.
  final String summary;

  /// `learning_units.duration_minutes`.
  final int durationMinutes;

  /// `learning_units.sequence`.
  final int stepNumber;

  /// Count of `learning_units` in the pathway.
  final int totalSteps;

  double get progress => totalSteps == 0 ? 0 : (stepNumber - 1) / totalSteps;
}

/// Position within the assigned learning pathway.
class PathwayProgress {
  const PathwayProgress({
    required this.title,
    required this.completedUnits,
    required this.totalUnits,
  });

  final String title;
  final int completedUnits;
  final int totalUnits;

  double get fraction => totalUnits == 0 ? 0 : completedUnits / totalUnits;
}

/// A scheduled, real-world commitment. This is the only item on Home that the
/// candidate cannot reschedule from inside the app, which is why it outranks
/// every learning surface below it.
class UpcomingInterview {
  const UpcomingInterview({
    required this.employerName,
    required this.location,
    required this.scheduledAt,
  });

  final String employerName;
  final String location;
  final DateTime scheduledAt;
}

abstract interface class HomeDashboardRepository {
  Future<Result<HomeDashboard?>> loadDashboard();
}
