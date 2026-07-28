import '../../../core/errors/result.dart';
import 'voice_interview.dart';

abstract interface class VoiceInterviewRepository {
  Future<Result<VoiceInterviewState>> load(String candidateId);

  Future<Result<VoiceInterviewState>> save(
    String candidateId,
    VoiceInterviewState state,
  );

  Future<Result<void>> delete(String candidateId);
}

class VoiceCaptureResult {
  const VoiceCaptureResult({required this.path, required this.durationSeconds});

  final String path;
  final int durationSeconds;
}

abstract interface class VoiceCaptureRepository {
  Future<Result<bool>> requestPermission();

  Future<Result<void>> start({
    required String sessionId,
    required String questionId,
  });

  Future<Result<VoiceCaptureResult>> stop();

  Future<void> cancel();

  Future<void> deleteLocalFile(String path);

  void dispose();
}

abstract interface class ResumableMediaUploadRepository {
  Future<Result<void>> queue({
    required String sessionId,
    required String questionId,
    required String localPath,
  });
}
