import 'dart:convert';
import 'dart:io';

const sourcePath = 'assets/books/swalathu_saadha.pdf';
const backupPath =
    'tool/backups/exact-corrections-20261029-213348/swalathu_saadha.pdf';
const outputPath = 'assets/books/swalathu_saadha_corrected.pdf';
const overlayObjectNumber = 204;

String _circlePath(double cx, double cy, double radius) {
  const k = 0.5522847498;
  final c = radius * k;
  return [
    '${cx + radius} $cy m',
    '${cx + radius} ${cy + c} ${cx + c} ${cy + radius} $cx ${cy + radius} c',
    '${cx - c} ${cy + radius} ${cx - radius} ${cy + c} ${cx - radius} $cy c',
    '${cx - radius} ${cy - c} ${cx - c} ${cy - radius} $cx ${cy - radius} c',
    '${cx + c} ${cy - radius} ${cx + radius} ${cy - c} ${cx + radius} $cy c',
    'f',
  ].join('\n');
}

void main() {
  final sourceFile = File(sourcePath);
  final backupFile = File(backupPath);
  if (!sourceFile.existsSync() || !backupFile.existsSync()) {
    throw StateError('The original PDF or its verified backup is missing.');
  }

  final sourceBytes = sourceFile.readAsBytesSync();
  final backupBytes = backupFile.readAsBytesSync();
  if (sourceBytes.length != backupBytes.length) {
    throw StateError('The original PDF does not match its backup.');
  }
  for (var i = 0; i < sourceBytes.length; i++) {
    if (sourceBytes[i] != backupBytes[i]) {
      throw StateError('The original PDF does not match its backup.');
    }
  }

  final source = latin1.decode(sourceBytes);
  final pageStart = source.indexOf('3 0 obj');
  final pageEnd = source.indexOf('endobj', pageStart);
  if (pageStart < 0 || pageEnd < 0) {
    throw FormatException('Could not locate the single Sa’adha page object.');
  }

  final originalPageDictionary =
      source.substring(pageStart + '3 0 obj'.length, pageEnd).trim();
  final pageDictionary = originalPageDictionary.replaceFirst(
    RegExp(r'/Contents\s+4\s+0\s+R'),
    '/Contents [4 0 R $overlayObjectNumber 0 R]',
  );
  if (pageDictionary == originalPageDictionary) {
    throw FormatException('Could not locate the original page content stream.');
  }

  final previousXrefMatch =
      RegExp(r'startxref\s+(\d+)').allMatches(source).lastOrNull;
  final idMatch = RegExp(r'/ID\s*(\[[^\]]+\])').firstMatch(source);
  if (previousXrefMatch == null || idMatch == null) {
    throw FormatException('Could not read the original PDF trailer.');
  }
  final previousXref = int.parse(previousXrefMatch.group(1)!);

  const pageHeight = 2138.4;
  const dotX = 130.0;
  const dotRadius = 9.0;
  const topFractions = [0.336, 0.561, 0.675];
  final circlePaths = topFractions
      .map((fraction) => _circlePath(
            dotX,
            pageHeight * (1 - fraction),
            dotRadius,
          ))
      .join('\n');
  final overlay = 'q\n1 1 1 rg\n$circlePaths\nQ\n';
  final overlayLength = utf8.encode(overlay).length;

  final update = StringBuffer('\n');
  final pageOffset = sourceBytes.length + 1;
  update.write('3 0 obj\n$pageDictionary\nendobj\n');
  final overlayOffset =
      sourceBytes.length + utf8.encode(update.toString()).length;
  update.write(
    '$overlayObjectNumber 0 obj\n'
    '<< /Length $overlayLength >>\n'
    'stream\n$overlay'
    'endstream\nendobj\n',
  );
  final xrefOffset = sourceBytes.length + utf8.encode(update.toString()).length;
  update
    ..write('xref\n')
    ..write('3 1\n${pageOffset.toString().padLeft(10, '0')} 00000 n \n')
    ..write(
      '$overlayObjectNumber 1\n'
      '${overlayOffset.toString().padLeft(10, '0')} 00000 n \n',
    )
    ..write(
      'trailer\n'
      '<< /Size ${overlayObjectNumber + 1} /Root 1 0 R /Info 96 0 R '
      '/ID ${idMatch.group(1)} /Prev $previousXref >>\n'
      'startxref\n$xrefOffset\n%%EOF\n',
    );

  final output = File(outputPath);
  output
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync([...sourceBytes, ...utf8.encode(update.toString())]);
  stdout.writeln(
    'Created $outputPath with three localized white vector patches; '
    'the original PDF and verified backup are unchanged.',
  );
}
