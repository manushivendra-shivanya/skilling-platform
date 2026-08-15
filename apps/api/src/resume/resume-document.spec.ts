import { extractDocxText, sniffResumeDocumentKind } from './resume-document';
import { makeDocx } from './testing/make-docx';

describe('sniffResumeDocumentKind', () => {
  it('recognises a PDF by its magic number', () => {
    const pdf = Buffer.from('%PDF-1.7\nnot really a pdf body', 'ascii');
    expect(sniffResumeDocumentKind(pdf)).toBe('pdf');
  });

  it('recognises a .docx by looking inside the zip, not just at the header', () => {
    expect(sniffResumeDocumentKind(makeDocx(['Asha Kumari']))).toBe('docx');
  });

  it('recognises a legacy .doc so it can be told apart from junk', () => {
    const ole2 = Buffer.concat([
      Buffer.from([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
      Buffer.alloc(64),
    ]);
    expect(sniffResumeDocumentKind(ole2)).toBe('doc');
  });

  it('rejects a zip that is not a Word document', () => {
    // A spreadsheet is also an OOXML zip -- stopping at the PK header
    // would hand mammoth a file it cannot read, and the candidate would
    // get a parse failure instead of "that is not a Word file".
    const xlsx = Buffer.concat([
      Buffer.from([0x50, 0x4b, 0x03, 0x04]),
      Buffer.from('xl/workbook.xml', 'ascii'),
    ]);
    expect(sniffResumeDocumentKind(xlsx)).toBe('unknown');
  });

  it('rejects an image, and does not trust a PDF-ish name inside it', () => {
    const png = Buffer.concat([
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      Buffer.from('resume.pdf', 'ascii'),
    ]);
    expect(sniffResumeDocumentKind(png)).toBe('unknown');
  });

  it('does not read past the end of a file shorter than any magic number', () => {
    expect(sniffResumeDocumentKind(Buffer.from('%PD', 'ascii'))).toBe(
      'unknown',
    );
    expect(sniffResumeDocumentKind(Buffer.alloc(0))).toBe('unknown');
  });
});

describe('extractDocxText', () => {
  it('returns every paragraph of a Word document as plain text', async () => {
    const docx = makeDocx([
      'Asha Kumari',
      'Warehouse Associate at ABC Logistics',
      'Forklift certified',
    ]);

    const text = await extractDocxText(docx);

    expect(text).toContain('Asha Kumari');
    expect(text).toContain('Warehouse Associate at ABC Logistics');
    expect(text).toContain('Forklift certified');
  });

  it('trims the extraction so an empty document is recognisably empty', async () => {
    expect(await extractDocxText(makeDocx([]))).toBe('');
  });
});
