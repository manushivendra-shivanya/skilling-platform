import '../../workplace_simulation/domain/simulation_enums.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import 'shifts_repository.dart';

/// Converts a completed [ShiftApplication] into [EvidenceRecord]s for the
/// Career Passport -- one per the shift's required competencies, mirroring
/// `micro_lessons/domain/micro_lesson_evidence_generation_service.dart`'s
/// shape. Uses `partnerAttested` rather than `systemObserved`: this is
/// attested by the site/employer's check-in/check-out flow, not directly
/// observed by Flora's own scoring engine, unlike WMS simulation evidence.
class ShiftEvidenceGenerationService {
  const ShiftEvidenceGenerationService();

  List<EvidenceRecord> generate(
    String candidateId,
    ShiftApplication application,
    Shift shift,
  ) {
    if (application.status != ShiftApplicationStatus.completed) {
      return const [];
    }
    return [
      for (final competencyId in shift.requiredCompetencyIds)
        EvidenceRecord(
          id: '${application.id}-$competencyId',
          candidateId: candidateId,
          attemptId: application.id,
          missionId: shift.id,
          missionVersion: '1',
          scenarioSeed: 0,
          competencyId: competencyId,
          // Completion-based, not a graded score -- there is no partial
          // credit for a real shift, only "worked it" or not.
          score: 100,
          evidenceType: EvidenceType.shiftCompletion,
          title: 'Completed a real shift: ${shift.roleTitle}',
          description:
              'Attendance verified by ${shift.siteName} check-in and check-out.',
          issuedAt: application.checkedOutAt ?? application.createdAt,
          verificationStatus: EvidenceVerificationStatus.partnerAttested,
        ),
    ];
  }
}
