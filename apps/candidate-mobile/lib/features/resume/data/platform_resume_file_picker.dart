import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/resume_file_picker.dart';

/// The device's own document picker.
///
/// `FileType.custom` with an explicit extension list, not `FileType.any`:
/// the picker itself then greys out files this app cannot read, which is
/// a better answer than accepting a photo and explaining afterwards.
///
/// Reads the file into memory rather than keeping a path, because the
/// bytes are what gets sent (base64 inside the parse request -- see
/// `ApiResumeParsingRepository.parseDocument`), and a content-provider
/// URI from Android's picker isn't a readable filesystem path anyway.
/// The size ceiling that makes holding a file in memory safe is enforced
/// by the caller before the bytes are used.
class PlatformResumeFilePicker implements ResumeFilePicker {
  const PlatformResumeFilePicker();

  @override
  Future<PickedResumeFile?> pickResumeFile() async {
    // `pickFile`, not `pickFiles`: file_picker 12 split single-file
    // selection into its own call and deprecated `allowMultiple`. It also
    // made the methods static (`FilePicker.pickFile`, not
    // `FilePicker.platform.pickFiles`) and returns the file directly
    // rather than wrapping it in a FilePickerResult.
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      // `.doc` is offered deliberately even though nothing can read it --
      // the server answers a legacy Word file with "save it as PDF or
      // .docx", which is more use than the picker silently hiding the
      // file the candidate is looking straight at.
      allowedExtensions: const ['pdf', 'docx', 'doc'],
    );
    if (file == null) return null;

    // `readAsBytes()`, not the old `withData: true` parameter, which
    // file_picker 12 deprecated in favour of reading on demand. Anything
    // the picker cannot actually read surfaces here rather than as a
    // silently-null `bytes` field.
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw ResumeFileUnreadableException(file.name);
    }
    if (bytes.isEmpty) {
      throw ResumeFileUnreadableException(file.name);
    }
    return PickedResumeFile(name: file.name, bytes: bytes);
  }
}
