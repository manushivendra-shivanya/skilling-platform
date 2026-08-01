import 'package:candidate_mobile/features/micro_lessons/data/asset_micro_lesson_clip_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip_validator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing test asset: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError('Binary assets are not used by these tests.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the warehouse micro-clip catalogue from assets', () async {
    const repository = AssetMicroLessonClipRepository();

    final result = await repository.loadClips();

    result.when(
      success: (clips) {
        expect(clips, hasLength(greaterThanOrEqualTo(7)));
        expect(clips.every((clip) => clip.durationSeconds == 10), isTrue);
        expect(
          clips.map((clip) => clip.id).toSet(),
          containsAll([
            'clip_receiving_frozen_001',
            'clip_receiving_supplier_001',
            'clip_putaway_ambient_001',
          ]),
        );
        expect(
          clips
              .where((clip) => clip.domain == MicroLessonDomain.putAway)
              .length,
          greaterThanOrEqualTo(2),
        );
        expect(
          clips.where((clip) => clip.hasVideoAsset).map((clip) => clip.id),
          containsAll([
            'clip_receiving_frozen_001',
            'clip_receiving_supplier_001',
            'clip_inspection_fnv_001',
          ]),
        );
      },
      failure: (failure) => fail(failure.message),
    );
  });

  test(
    'validates all shipped clips as ten-second assessment-ready content',
    () async {
      const repository = AssetMicroLessonClipRepository();
      final result = await repository.loadClips();

      result.when(
        success: (clips) {
          final errors = validateMicroLessonClipCatalogue(clips);
          expect(errors, isEmpty);
          expect(
            clips.every(
              (clip) =>
                  clip.scoringRules.evidenceSource == 'systemObserved' &&
                  !clip.scoringRules.technicalFailuresScoreable,
            ),
            isTrue,
          );
          expect(
            clips.every(
              (clip) => clip.modes.contains(MicroLessonMode.assessment),
            ),
            isTrue,
          );
        },
        failure: (failure) => fail(failure.message),
      );
    },
  );

  test('rejects invalid catalogues before they reach the UI', () async {
    const invalidJson = '''
{
  "clips": [
    {
      "id": "bad",
      "title": "Bad clip",
      "domain": "receiving",
      "role": "Receiving Associate",
      "processArea": "Receiving Dock",
      "temperatureZone": "frozen",
      "durationSeconds": 12,
      "videoUrl": null,
      "thumbnailUrl": null,
      "transcript": "Short transcript",
      "description": "Invalid duration and answer.",
      "expectedObservation": "Observe the issue.",
      "expectedDecision": "Escalate.",
      "competencyTags": ["receiving"],
      "lessonContent": "Lesson text",
      "assessmentQuestion": "Question?",
      "answerOptions": [
        {
          "id": "a",
          "label": "A",
          "feedback": "Feedback"
        },
        {
          "id": "b",
          "label": "B",
          "feedback": "Feedback"
        }
      ],
      "correctAnswer": "missing",
      "scoringRules": {
        "maxPoints": 10,
        "correctAnswerPoints": 10,
        "evidenceSource": "systemObserved",
        "technicalFailuresScoreable": true
      },
      "auditEvents": []
    }
  ]
}
''';
    final repository = AssetMicroLessonClipRepository(
      assetBundle: _StringAssetBundle({'clips.json': invalidJson}),
      assetPath: 'clips.json',
    );

    final result = await repository.loadClips();

    result.when(
      success: (_) => fail('Invalid catalogue should fail validation.'),
      failure: (failure) {
        expect(failure.message, contains('durationSeconds'));
        expect(failure.message, contains('correctAnswer'));
        expect(failure.message, contains('technical failures'));
      },
    );
  });
}
