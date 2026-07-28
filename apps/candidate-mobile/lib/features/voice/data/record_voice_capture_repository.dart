import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/voice_interview_repository.dart';

class RecordVoiceCaptureRepository implements VoiceCaptureRepository {
  RecordVoiceCaptureRepository({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Future<Result<bool>> requestPermission() async {
    try {
      return Success(await _recorder.hasPermission());
    } catch (error, stackTrace) {
      return ResultFailure(
        PermissionFailure(
          'Microphone permission could not be checked. Review app permissions and retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> start({
    required String sessionId,
    required String questionId,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final safeSession = sessionId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final safeQuestion = questionId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final path =
          '${directory.path}/voice-$safeSession-$safeQuestion-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _stopwatch
        ..reset()
        ..start();
      return const Success(null);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Recording could not start. No score was changed; please retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<VoiceCaptureResult>> stop() async {
    try {
      final path = await _recorder.stop();
      _stopwatch.stop();
      if (path == null) {
        throw const FileSystemException('Recorder returned no audio path');
      }
      return Success(
        VoiceCaptureResult(
          path: path,
          durationSeconds: _stopwatch.elapsed.inSeconds.clamp(1, 300),
        ),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Recording could not be saved. This technical failure will not affect feedback.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> cancel() async {
    _stopwatch.stop();
    await _recorder.cancel();
  }

  @override
  Future<void> deleteLocalFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  void dispose() => _recorder.dispose();
}

class LocalQueuedMediaUploadRepository
    implements ResumableMediaUploadRepository {
  const LocalQueuedMediaUploadRepository();

  @override
  Future<Result<void>> queue({
    required String sessionId,
    required String questionId,
    required String localPath,
  }) async {
    return const Success(null);
  }
}

class InMemoryVoiceCaptureRepository implements VoiceCaptureRepository {
  InMemoryVoiceCaptureRepository({
    this.permissionGranted = true,
    this.capturedPath = '/tmp/test-answer.m4a',
  });

  bool permissionGranted;
  String capturedPath;
  bool isRecording = false;
  final List<String> deletedPaths = [];

  @override
  Future<Result<bool>> requestPermission() async => Success(permissionGranted);

  @override
  Future<Result<void>> start({
    required String sessionId,
    required String questionId,
  }) async {
    isRecording = true;
    return const Success(null);
  }

  @override
  Future<Result<VoiceCaptureResult>> stop() async {
    isRecording = false;
    return Success(VoiceCaptureResult(path: capturedPath, durationSeconds: 12));
  }

  @override
  Future<void> cancel() async => isRecording = false;

  @override
  Future<void> deleteLocalFile(String path) async {
    deletedPaths.add(path);
  }

  @override
  void dispose() {}
}
