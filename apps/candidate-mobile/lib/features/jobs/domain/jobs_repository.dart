import '../../../core/errors/result.dart';

class JobOpportunity {
  const JobOpportunity({
    required this.id,
    required this.title,
    required this.employer,
    required this.location,
    required this.isSupervisorRole,
    required this.matchReason,
  });

  final String id;
  final String title;
  final String employer;
  final String location;
  final bool isSupervisorRole;
  final String matchReason;
}

abstract interface class JobsRepository {
  Future<Result<List<JobOpportunity>>> loadJobs();

  Future<Result<Set<String>>> readAppliedJobIds(String candidateId);

  Future<Result<void>> saveApplication(String candidateId, String jobId);
}
