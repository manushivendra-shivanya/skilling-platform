import * as mammoth from 'mammoth';

/**
 * The upload formats this service can do something honest with.
 *
 * `doc` is recognised deliberately even though nothing can read it -- a
 * candidate who uploads a legacy Word file deserves "save it as PDF or
 * .docx" rather than the same "unsupported file" wall an image or a zip
 * gets. `unknown` is everything else.
 */
export type ResumeDocumentKind = 'pdf' | 'docx' | 'doc' | 'unknown';

// Magic numbers, checked in order of how cheaply they disambiguate.
const PDF_MAGIC = Buffer.from('%PDF-', 'ascii');
// Every OOXML file (.docx/.xlsx/.pptx) is a zip; only the archive's own
// contents tell the three apart, which is why isDocxArchive below looks
// inside rather than stopping at the zip header.
const ZIP_MAGIC = Buffer.from([0x50, 0x4b, 0x03, 0x04]);
// OLE2 compound file -- the pre-2007 .doc/.xls/.ppt container.
const OLE2_MAGIC = Buffer.from([
  0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1,
]);

/**
 * Identifies an upload from its own bytes, never from the mime type or
 * filename the client sent.
 *
 * Both of those are untrustworthy in ordinary use, not just under attack:
 * Android's document picker routinely reports `application/octet-stream`
 * for a perfectly good PDF depending on which app provided the file. They
 * are also the difference between handing Gemini a real PDF and handing
 * it arbitrary bytes labelled as one.
 */
export function sniffResumeDocumentKind(bytes: Buffer): ResumeDocumentKind {
  if (bytes.subarray(0, PDF_MAGIC.length).equals(PDF_MAGIC)) return 'pdf';
  if (bytes.subarray(0, OLE2_MAGIC.length).equals(OLE2_MAGIC)) return 'doc';
  if (bytes.subarray(0, ZIP_MAGIC.length).equals(ZIP_MAGIC)) {
    return isDocxArchive(bytes) ? 'docx' : 'unknown';
  }
  return 'unknown';
}

/**
 * True when a zip archive is specifically a Word document.
 *
 * Every OOXML package stores its part names as plain, uncompressed bytes
 * in the local file headers, so scanning for `word/document.xml` reads
 * the archive's own table of contents without needing to inflate
 * anything. A spreadsheet (`xl/workbook.xml`) or a deck therefore fails
 * this check and is reported as `unknown` -- which is the point: mammoth
 * would otherwise be handed a file it cannot make sense of, and the
 * candidate would get a parse failure instead of "that isn't a Word
 * file".
 */
function isDocxArchive(bytes: Buffer): boolean {
  return bytes.includes(Buffer.from('word/document.xml', 'ascii'));
}

/**
 * Pulls the plain text out of a .docx.
 *
 * Word documents are not sent to the model as-is the way PDFs are: the
 * model reads PDF pages natively but has no .docx renderer, so the choice
 * is extracted text or nothing. mammoth walks the document body --
 * including table cells, which matter because a great many resume
 * templates are one big table -- and returns paragraph text.
 *
 * Throws when the archive isn't readable as a document, which
 * `ResumeService` turns into the same "temporarily unavailable" response
 * as any other extraction failure.
 */
export async function extractDocxText(bytes: Buffer): Promise<string> {
  const { value } = await mammoth.extractRawText({ buffer: bytes });
  return value.trim();
}
