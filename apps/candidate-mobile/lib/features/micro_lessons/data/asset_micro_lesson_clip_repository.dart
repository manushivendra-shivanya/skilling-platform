import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/micro_lesson_clip.dart';
import '../domain/micro_lesson_clip_repository.dart';
import '../domain/micro_lesson_clip_validator.dart';

class AssetMicroLessonClipRepository implements MicroLessonClipRepository {
  const AssetMicroLessonClipRepository({
    this.assetBundle,
    this.assetPath = 'assets/micro_lessons/warehouse_clips.json',
    this.cdnBaseUrl = '',
  });

  final AssetBundle? assetBundle;
  final String assetPath;
  final String cdnBaseUrl;

  AssetBundle get _effectiveBundle => assetBundle ?? rootBundle;

  @override
  Future<Result<List<MicroLessonClip>>> loadClips() async {
    try {
      final raw = await _effectiveBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final clips = (decoded['clips'] as List<Object?>)
          .map((item) => MicroLessonClip.fromJson(item as Map<String, Object?>))
          .map(_resolveRemoteVideoUrl)
          .toList(growable: false);
      final errors = validateMicroLessonClipCatalogue(clips);
      if (errors.isNotEmpty) {
        return ResultFailure(
          ValidationFailure(
            'Micro-lesson clip catalogue is invalid: ${errors.join(', ')}',
          ),
        );
      }
      return Success(clips);
    } on FormatException catch (error, stackTrace) {
      return ResultFailure(
        ValidationFailure(
          'Micro-lesson clip catalogue contains invalid content.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on Object catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Could not load micro-lesson clips.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  MicroLessonClip _resolveRemoteVideoUrl(MicroLessonClip clip) {
    final path = clip.cloudflareVideoPath?.trim();
    if (path == null || path.isEmpty) {
      return clip;
    }

    final baseUri = Uri.tryParse(cdnBaseUrl.trim());
    if (baseUri == null || !baseUri.hasScheme) {
      return clip;
    }

    final normalizedBase = cdnBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    return clip.copyWith(
      videoUrl: '$normalizedBase/$normalizedPath',
      fallbackVideoUrl: clip.videoUrl,
    );
  }
}
