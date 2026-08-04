import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/presentation/micro_lesson_clip_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMicroLessonClipRepository implements MicroLessonClipRepository {
  const _FakeMicroLessonClipRepository(this.clips);

  final List<MicroLessonClip> clips;

  @override
  Future<Result<List<MicroLessonClip>>> loadClips() async => Success(clips);
}

void main() {
  test(
    'groups clips by domain and competency without scoring side effects',
    () async {
      final container = ProviderContainer(
        overrides: [
          microLessonClipRepositoryProvider.overrideWithValue(
            _FakeMicroLessonClipRepository([
              _clip(
                id: 'receiving',
                module: MicroLessonModule.inward,
                sequenceNumber: 1,
                domain: MicroLessonDomain.receiving,
                competencyTags: ['cold_chain_receiving_check'],
              ),
              _clip(
                id: 'putaway',
                module: MicroLessonModule.inward,
                sequenceNumber: 2,
                domain: MicroLessonDomain.putAway,
                competencyTags: ['putaway_scan_accuracy'],
              ),
              _clip(
                id: 'dispatch',
                module: MicroLessonModule.dispatch,
                sequenceNumber: 1,
                domain: MicroLessonDomain.dispatch,
                competencyTags: ['dispatch_order_merge'],
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        microLessonClipControllerProvider.future,
      );

      expect(state.clipsForDomain(MicroLessonDomain.receiving), hasLength(1));
      expect(state.clipsForDomain(MicroLessonDomain.putAway), hasLength(1));
      expect(
        state.clipsForModule(MicroLessonModule.inward).map((clip) => clip.id),
        ['receiving', 'putaway'],
      );
      expect(
        state.clipsForModule(MicroLessonModule.dispatch).single.id,
        'dispatch',
      );
      expect(
        state.clipsForCompetency('cold_chain_receiving_check').single.id,
        'receiving',
      );
    },
  );
}

MicroLessonClip _clip({
  required String id,
  required MicroLessonModule module,
  required int sequenceNumber,
  required MicroLessonDomain domain,
  required List<String> competencyTags,
}) {
  return MicroLessonClip(
    id: id,
    title: 'Clip $id',
    module: module,
    sequenceNumber: sequenceNumber,
    domain: domain,
    role: 'Warehouse Operations Associate',
    processArea: 'Receiving Dock',
    temperatureZone: TemperatureZone.mixed,
    durationSeconds: 10,
    videoUrl: null,
    cloudflareVideoPath: null,
    fallbackVideoUrl: null,
    thumbnailUrl: null,
    transcript: 'Transcript',
    description: 'Description',
    expectedObservation: 'Observation',
    expectedDecision: 'Decision',
    competencyTags: competencyTags,
    lessonContent: 'Lesson',
    assessmentQuestion: 'Question?',
    answerOptions: const [
      ClipAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
      ClipAnswerOption(id: 'wrong', label: 'Wrong', feedback: 'Try again'),
    ],
    correctAnswerId: 'correct',
    scoringRules: const ClipScoringRules(
      maxPoints: 10,
      correctAnswerPoints: 10,
      evidenceSource: 'systemObserved',
      technicalFailuresScoreable: false,
    ),
    auditEvents: const [
      ClipAuditEventDefinition(
        eventType: 'clipAnswerSubmitted',
        when: 'onAnswerSubmit',
      ),
    ],
  );
}
