import 'package:file_picker/file_picker.dart';

import '../domain/resume_file_picker.dart';

/// The device's own document picker.
///
/// `withData: true` loads the file into memory rather than handing back a
/// path. Two reasons: the bytes are what gets sent (base64 inside the
/// parse request -- see `ApiResumeParsingRepository.parseDocument`), and
/// a content-provider URI from Android's picker isn't a readable
/// filesystem path anyway. The size ceiling that makes holding a file in
/// memory safe is enforced by the caller before the bytes are used.
///
/// `FileType.custom` with an explicit extension list, not `FileType.any`:
/// the picker itself then greys out files this app cannot read, which is
/// a better answer than accepting a photo and explaining afterwards.
class PlatformResumeFilePicker implements ResumeFilePicker {
  const PlatformResumeFilePicker();

  @override
  Future<PickedResumeFile?> pickResumeFile() async {
    // Static, not `FilePicker.platform.pickFiles` -- file_picker 11 made
    // FilePicker an `abstract final class` whose methods are static and
    // delegate to FilePickerPlatform.instance internally.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      // `.doc` is offered deliberately even though nothing can read it --
      // the server answers a legacy Word file with "save it as PDF or
      // .docx", which is more use than the picker silently hiding the
      // file the candidate is looking straight at.
      allowedExtensions: const ['pdf', 'docx', 'doc'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw ResumeFileUnreadableException(file.name);
    }
    return PickedResumeFile(name: file.name, bytes: bytes);
  }
}
