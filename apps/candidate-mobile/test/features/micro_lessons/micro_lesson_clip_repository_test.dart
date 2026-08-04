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
        expect(clips, hasLength(17));
        expect(clips.every((clip) => clip.durationSeconds == 10), isTrue);
        expect(
          clips.map((clip) => clip.id).toSet(),
          containsAll([
            'clip_receiving_frozen_001',
            'clip_receiving_supplier_001',
            'clip_receiving_fnv_count_001',
            'clip_receiving_fnv_001',
            'clip_inspection_fnv_001',
            'clip_putaway_dairy_001',
            'clip_putaway_ambient_001',
            'clip_processing_moq_001',
            'clip_processing_fnv_packing_001',
            'clip_picking_frozen_001',
            'clip_picking_ambient_001',
            'clip_dispatch_merge_001',
            'clip_dispatch_staging_001',
            'clip_dispatch_loading_001',
            'clip_delivery_handover_001',
            'clip_returns_driver_settlement_001',
            'clip_returns_quarantine_001',
          ]),
        );
        expect(clips.first.module, MicroLessonModule.inward);
        expect(clips.first.sequenceNumber, 1);
        expect(clips.last.module, MicroLessonModule.dispatch);
        expect(clips.last.sequenceNumber, 8);
        expect(
          clips.where((clip) => clip.module == MicroLessonModule.inward),
          hasLength(7),
        );
        expect(
          clips.where((clip) => clip.module == MicroLessonModule.processing),
          hasLength(2),
        );
        expect(
          clips.where((clip) => clip.module == MicroLessonModule.dispatch),
          hasLength(8),
        );
        expect(
          clips
              .where((clip) => clip.domain == MicroLessonDomain.putAway)
              .length,
          greaterThanOrEqualTo(2),
        );
        expect(clips.where((clip) => clip.hasVideoAsset), hasLength(16));
        expect(
          clips.where((clip) => !clip.hasVideoAsset).single.id,
          'clip_returns_quarantine_001',
        );
        expect(
          clips
              .where((clip) => clip.hasVideoAsset)
              .every((clip) => clip.cloudflareVideoPath != null),
          isTrue,
        );
      },
      failure: (failure) => fail(failure.message),
    );
  });

  test(
    'resolves Cloudflare CDN video URLs with local asset fallback',
    () async {
      const repository = AssetMicroLessonClipRepository(
        cdnBaseUrl: 'https://cdn.example.com/training/',
      );

      final result = await repository.loadClips();

      result.when(
        success: (clips) {
          final clip = clips.firstWhere(
            (clip) => clip.id == 'clip_receiving_supplier_001',
          );
          expect(
            clip.videoUrl,
            'https://cdn.example.com/training/'
            'micro-lessons/warehouse/v1/inward/01-clip_receiving_supplier_001/'
            'receiving_wrong_supplier_stop.mp4',
          );
          expect(
            clip.fallbackVideoUrl,
            'asset://assets/micro_lessons/videos/'
            'receiving_wrong_supplier_stop.mp4',
          );
          expect(clip.hasRemoteVideo, isTrue);

          final placeholder = clips.firstWhere(
            (clip) => clip.id == 'clip_returns_quarantine_001',
          );
          expect(placeholder.videoUrl, isNull);
          expect(placeholder.cloudflareVideoPath, isNull);
        },
        failure: (failure) => fail(failure.message),
      );
    },
  );

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
      "module": "inward",
      "sequenceNumber": 1,
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
