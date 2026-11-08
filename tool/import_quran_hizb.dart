// Optional offline 604-page Hizb metadata importer.
// Documented source: https://qurani.ai/en/docs/1-general-apis/page/Get_All_Pages_Metadata_v1_page_metadata_get
// Generates an auxiliary JSON file; never modifies Quran verse text or PDF.
import 'dart:convert';
import 'dart:io';

const endpoint = 'https://api.qurani.ai/gw/qh/v1/page/metadata';
const output = 'assets/data/quran_page_hizb.json';

Future<void> main() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);
  try {
    final req = await client.getUrl(Uri.parse(endpoint));
    final res = await req.close();
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException('Hizb metadata HTTP ${res.statusCode}');
    }
    final root = jsonDecode(await utf8.decoder.bind(res).join());
    if (root is! Map || root['data'] is! List) {
      throw const FormatException('Invalid page metadata response.');
    }
    final entries = root['data'] as List;
    if (entries.length != 604) {
      throw FormatException('Expected 604 metadata entries, got ${entries.length}');
    }
    final hizbByPage = <String, int>{};
    for (final entry in entries) {
      if (entry is! Map) throw const FormatException('Invalid entry');
      final page = entry['number'];
      final hizbs = entry['hizbNumbers'];
      if (page is! int || page < 1 || page > 604 ||
          hizbs is! List || hizbs.isEmpty ||
          hizbs.first is! int) {
        throw const FormatException('Invalid page or hizb');
      }
      final hizb = hizbs.first as int;
      if (hizb < 1 || hizb > 60) {
        throw FormatException('Invalid Hizb $hizb');
      }
      hizbByPage[page.toString()] = hizb;
    }
    if (hizbByPage.length != 604 || hizbByPage['1'] != 1 ||
        hizbByPage['604'] != 60) {
      throw const FormatException('Incomplete Hizb map.');
    }
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(hizbByPage), flush: true);
    stdout.writeln('Saved exact Hizb metadata for all 604 pages: $output');
    stdout.writeln("Page 77 Hizb: ${hizbByPage['77']}");
  } finally {
    client.close(force: true);
  }
}
