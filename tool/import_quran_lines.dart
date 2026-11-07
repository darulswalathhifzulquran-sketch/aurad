// Development-only importer of Quran.com-style Madani Mushaf line breaks.
// Source: https://github.com/blueheron786/line-by-line-quran
// Verify both distribution rights and all 604 pages against a trusted
// printed Mushaf before shipping. Does not overwrite the existing Quran PDF.
import 'dart:convert';
import 'dart:io';

const sourceUrl =
    'https://raw.githubusercontent.com/blueheron786/line-by-line-quran/main/pages.json';
const outputPath = 'assets/data/quran_lines.json';

Future<void> main() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.getUrl(Uri.parse(sourceUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Download failed: HTTP ' + response.statusCode.toString());
    }
    final raw = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(raw);
    if (parsed is! List || parsed.length != 604) {
      throw const FormatException('Expected exactly 604 Quran pages.');
    }
    final pages = <List<String>>[];
    for (var i = 0; i < parsed.length; i++) {
      final page = parsed[i];
      if (page is! List || page.isEmpty || page.length > 16) {
        throw FormatException('Unexpected lines on page ' + (i + 1).toString());
      }
      final lines = <String>[];
      for (final line in page) {
        if (line is! String) {
          throw FormatException('Non-text line on page ' + (i + 1).toString());
        }
        lines.add(line.trim());
      }
      if (lines.every((line) => line.isEmpty)) {
        throw FormatException('Empty page ' + (i + 1).toString());
      }
      pages.add(lines);
    }
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(pages), flush: true);
    stdout.writeln('Saved 604 Quran pages to ' + outputPath);
    stdout.writeln('Page 77 first nonempty line:');
    stdout.writeln(pages[76].firstWhere((line) => line.isNotEmpty));
    stdout.writeln(
      'IMPORTANT: Verify Arabic text and data rights before release.',
    );
  } finally {
    client.close(force: true);
  }
}
