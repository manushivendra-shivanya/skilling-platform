import 'dart:typed_data';

/// A resume file the candidate chose, already loaded into memory.
class PickedResumeFile {
  const PickedResumeFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  int get sizeInBytes => bytes.length;
}

/// Wraps the platform document picker behind an interface.
///
/// Exists so the import screen can be driven in a widget test: the real
/// picker is a platform channel that never completes under
/// `flutter test`, which would leave the upload path -- the whole point
/// of the screen -- covered by nothing.
abstract interface class ResumeFilePicker {
  /// Returns null when the candidate closed the picker without choosing
  /// a file. That is an ordinary outcome, not an error, and the screen
  /// treats it as one.
  ///
  /// Throws when the picker returned a file whose bytes could not be
  /// read -- a real failure the candidate needs telling about.
  Future<PickedResumeFile?> pickResumeFile();
}

/// Thrown by [ResumeFilePicker.pickResumeFile] when a file was chosen but
/// its contents could not be loaded.
class ResumeFileUnreadableException implements Exception {
  const ResumeFileUnreadableException(this.fileName);

  final String fileName;

  @override
  String toString() => 'Could not read the contents of "$fileName".';
}
