// Bulk content importer for the Riyad al-Adhkar (al_auradu) app.
//
// Run from the project root (the folder that contains pubspec.yaml):
//     dart tool/import_content.dart --dry-run     (preview, changes nothing)
//     dart tool/import_content.dart               (real import)
//
// It scans the `content/` folder (including nested folders), converts
// .txt / .md / .json files into library items and merges them into
// assets/data/library.json. Existing content is never overwritten.
import 'dart:convert';
import 'dart:io';

const String kLibraryPath = 'assets/data/library.json';
const String kImportDir = '_import';

final RegExp _arabicRe =
    RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
final RegExp _malRe = RegExp(r'[\u0D00-\u0D7F]');
final RegExp _latinRe = RegExp(r'[A-Za-z]');
final RegExp _harakatRe = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]');
final RegExp _pageBreak = RegExp(
    r'^\s*(?:-{3,}|={3,}|\*{3,}|<!--\s*page\s*-->|\[page\]|\[\[page\]\])\s*$',
    caseSensitive: false);
final RegExp _imgRe = RegExp(r'!\[[^\]]*\]\([^)]*\)');
final RegExp _linkRe = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final RegExp _commentRe = RegExp(r'<!--.*?-->');

// ---------------------------------------------------------------- helpers

class ImportError implements Exception {
  final String message;
  ImportError(this.message);
}

class Doc {
  String? title;
  String? ar;
  String? en;
  String? category;
  String? idHint;
  List<dynamic> pages;
  String src;
  bool flow;
  Doc({
    required this.pages,
    required this.src,
    this.title,
    this.ar,
    this.en,
    this.category,
    this.idHint,
    this.flow = false,
  });
}

class ParseResult {
  final List<Doc> docs = [];
  final List<String> warnings = [];
  final List<Map<String, dynamic>> categories = [];
  String? error;
}

String hashText(String s) {
  var a = 0x811C9DC5;
  var b = 0x9747B28C;
  for (final r in s.runes) {
    a ^= r;
    a = (a * 16777619) & 0xFFFFFFFF;
    b ^= r;
    b = (b * 16777619 + 7) & 0xFFFFFFFF;
  }
  return '${a.toRadixString(16)}${b.toRadixString(16)}${s.length}';
}

String sig(String s) => s.replaceAll(RegExp(r'\s+'), '');

String keyOf(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
String latinKey(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
String arKey(String s) =>
    s.replaceAll(_harakatRe, '').replaceAll(RegExp(r'\s+'), ' ').trim();

String normalizeNl(String s) => s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String decodeFile(List<int> bytes) {
  try {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add(bytes[i] | (bytes[i + 1] << 8));
      }
      return String.fromCharCodes(units);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    final s = utf8.decode(bytes);
    return (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) ? s.substring(1) : s;
  } on FormatException {
    throw ImportError(
        'Not valid UTF-8 text. Open it in Notepad and Save As -> Encoding: UTF-8.');
  }
}

List<int> counts(String s) => [
      _arabicRe.allMatches(s).length,
      _malRe.allMatches(s).length,
      _latinRe.allMatches(s).length,
    ];

String? compareCounts(List<int> a, List<int> b, {required bool latin}) {
  const names = ['Arabic', 'Malayalam', 'English'];
  final n = latin ? 3 : 2;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) {
      return 'Text check failed: ${a[i]} ${names[i]} letters in the file but '
          '${b[i]} in the pages. Import cancelled so no text is lost.';
    }
  }
  return null;
}

String tidy(String s) {
  final lines =
      s.split('\n').map((l) => l.replaceAll(RegExp(r'[ \t]+$'), '')).toList();
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String plainOfPage(dynamic p) {
  if (p is String) return p;
  if (p is Map && p['blocks'] is List) {
    final b = StringBuffer();
    for (final blk in p['blocks'] as List) {
      if (blk is! Map) continue;
      final t = blk['t'];
      if (t == 'text') {
        b.writeln(blk['v'] ?? '');
      } else if (t == 'table') {
        final head = (blk['head'] as List?) ?? const [];
        final rows = (blk['rows'] as List?) ?? const [];
        for (final c in head) {
          b.writeln(c);
        }
        for (final r in rows) {
          for (final c in (r as List)) {
            b.writeln(c);
          }
        }
      }
    }
    return b.toString();
  }
  return '';
}

String joinPlain(List<dynamic> pages) => pages.map(plainOfPage).join('\n');

String contentHash(List<dynamic> pages) => hashText(sig(joinPlain(pages)));

// ------------------------------------------------------------ pagination

List<String> splitLongLine(String line, int maxChars) {
  final out = <String>[];
  var cur = StringBuffer();
  var len = 0;
  for (final w in line.split(' ')) {
    if (len + w.length + 1 > maxChars && len > 0) {
      out.add(cur.toString().trim());
      cur = StringBuffer();
      len = 0;
    }
    cur.write(w);
    cur.write(' ');
    len += w.length + 1;
  }
  final t = cur.toString().trim();
  if (t.isNotEmpty) out.add(t);
  return out;
}

List<String> paginateChunk(String chunk, int maxChars) {
  if (chunk.length <= maxChars) return [chunk];
  final pages = <String>[];
  var buf = StringBuffer();
  var len = 0;
  void flush() {
    final t = buf.toString().trim();
    if (t.isNotEmpty) pages.add(t);
    buf = StringBuffer();
    len = 0;
  }

  for (final line in chunk.split('\n')) {
    if (line.length > maxChars) {
      flush();
      pages.addAll(splitLongLine(line, maxChars));
      continue;
    }
    final add = line.length + 1;
    if (len + add > maxChars && len > 0) flush();
    buf.write(line);
    buf.write('\n');
    len += add;
  }
  flush();
  return pages;
}

/// Splits plain text into pages: explicit page breaks first (a line of ---,
/// === or <!-- page -->, or a form-feed), then by size.
List<String> buildTextPages(String body, int maxChars) {
  final t = body.replaceAll('\f', '\n---\n');
  final chunks = <String>[];
  var cur = <String>[];
  void close() {
    final c = tidy(cur.join('\n'));
    if (c.isNotEmpty) chunks.add(c);
    cur = <String>[];
  }

  for (final line in t.split('\n')) {
    if (_pageBreak.hasMatch(line)) {
      close();
    } else {
      cur.add(line);
    }
  }
  close();
  final pages = <String>[];
  for (final c in chunks) {
    final parts = paginateChunk(c, maxChars);
    if (sig(c) != sig(parts.join())) {
      throw ImportError('Internal check failed while splitting pages.');
    }
    pages.addAll(parts);
  }
  return pages;
}

// ------------------------------------------------- Word / PowerPoint files

int _u16(List<int> b, int o) => b[o] | (b[o + 1] << 8);
int _u32(List<int> b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

/// Reads the XML parts we need out of a .docx / .pptx (they are zip files).
Map<String, List<int>> readOfficeZip(List<int> b) {
  var eocd = -1;
  final stop = b.length - 22 - 65535;
  for (var i = b.length - 22; i >= 0 && i >= stop; i--) {
    if (_u32(b, i) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) {
    throw ImportError('Not a valid Word/PowerPoint file (.docx/.pptx). '
        'Old .doc/.ppt files must be re-saved as .docx/.pptx.');
  }
  final count = _u16(b, eocd + 10);
  var p = _u32(b, eocd + 16);
  final out = <String, List<int>>{};
  for (var n = 0; n < count; n++) {
    if (p + 46 > b.length || _u32(b, p) != 0x02014b50) break;
    final method = _u16(b, p + 10);
    final csize = _u32(b, p + 20);
    final nameLen = _u16(b, p + 28);
    final extraLen = _u16(b, p + 30);
    final commentLen = _u16(b, p + 32);
    final localOff = _u32(b, p + 42);
    final name =
        utf8.decode(b.sublist(p + 46, p + 46 + nameLen), allowMalformed: true);
    p += 46 + nameLen + extraLen + commentLen;
    if (!name.endsWith('.xml')) continue;
    if (!(name == 'word/document.xml' || name.startsWith('ppt/slides/slide'))) {
      continue;
    }
    final lNameLen = _u16(b, localOff + 26);
    final lExtraLen = _u16(b, localOff + 28);
    final start = localOff + 30 + lNameLen + lExtraLen;
    final data = b.sublist(start, start + csize);
    if (method == 0) {
      out[name] = data;
    } else if (method == 8) {
      out[name] = ZLibDecoder(raw: true).convert(data);
    }
  }
  return out;
}

String xmlUnescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
    .replaceAllMapped(RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)))
    .replaceAll('&amp;', '&');

String mdTable(List<List<String>> rows) {
  if (rows.isEmpty) return '';
  var cols = 0;
  for (final r in rows) {
    if (r.length > cols) cols = r.length;
  }
  if (cols == 0) return '';
  String line(List<String> r) {
    final cells = <String>[];
    for (var i = 0; i < cols; i++) {
      cells.add(i < r.length ? r[i].replaceAll('|', '/').trim() : '');
    }
    return '| ${cells.join(' | ')} |';
  }

  final b = StringBuffer();
  b.writeln(line(rows.first));
  b.writeln('|${List.filled(cols, '---').join('|')}|');
  for (final r in rows.skip(1)) {
    b.writeln(line(r));
  }
  return b.toString();
}

String docxParagraph(String p) {
  final b = StringBuffer();
  final re = RegExp(
      r'<w:t(?:\s[^>]*)?>(.*?)</w:t>|<w:br\s+w:type="page"\s*/>|<w:tab\s*/>|<w:br\s*/>|<w:cr\s*/>',
      dotAll: true);
  for (final m in re.allMatches(p)) {
    final t = m.group(1);
    if (t != null) {
      b.write(xmlUnescape(t));
    } else {
      final tag = m.group(0)!;
      if (tag.contains('w:type="page"')) {
        b.write('\f');
      } else if (tag.startsWith('<w:tab')) {
        b.write(' ');
      } else {
        b.write('\n');
      }
    }
  }
  return b.toString();
}

String docxToMd(String xml) {
  final body = RegExp(r'<w:body>(.*)</w:body>', dotAll: true).firstMatch(xml);
  final src = body?.group(1) ?? xml;
  final items = RegExp(
      r'<w:tbl>.*?</w:tbl>|<w:p(?:\s[^>]*)?>.*?</w:p>',
      dotAll: true);
  final out = StringBuffer();
  for (final m in items.allMatches(src)) {
    final chunk = m.group(0)!;
    if (chunk.startsWith('<w:tbl>')) {
      final rows = <List<String>>[];
      for (final r in RegExp(r'<w:tr(?:\s[^>]*)?>.*?</w:tr>', dotAll: true)
          .allMatches(chunk)) {
        final cells = <String>[];
        for (final c in RegExp(r'<w:tc(?:\s[^>]*)?>.*?</w:tc>', dotAll: true)
            .allMatches(r.group(0)!)) {
          final paras = RegExp(r'<w:p(?:\s[^>]*)?>.*?</w:p>', dotAll: true)
              .allMatches(c.group(0)!)
              .map((x) => docxParagraph(x.group(0)!).replaceAll('\n', ' ').trim())
              .where((t) => t.isNotEmpty);
          cells.add(paras.join(' '));
        }
        rows.add(cells);
      }
      out.writeln();
      out.write(mdTable(rows));
      out.writeln();
    } else {
      out.writeln(docxParagraph(chunk));
    }
  }
  return out.toString();
}

String pptxSlideToMd(String xml) {
  final items = RegExp(r'<a:tbl>.*?</a:tbl>|<a:p(?:\s[^>]*)?>.*?</a:p>',
      dotAll: true);
  String para(String p) {
    final b = StringBuffer();
    for (final m in RegExp(r'<a:t(?:\s[^>]*)?>(.*?)</a:t>|<a:br\s*/>',
            dotAll: true)
        .allMatches(p)) {
      final t = m.group(1);
      b.write(t != null ? xmlUnescape(t) : '\n');
    }
    return b.toString();
  }

  final out = StringBuffer();
  for (final m in items.allMatches(xml)) {
    final chunk = m.group(0)!;
    if (chunk.startsWith('<a:tbl>')) {
      final rows = <List<String>>[];
      for (final r in RegExp(r'<a:tr(?:\s[^>]*)?>.*?</a:tr>', dotAll: true)
          .allMatches(chunk)) {
        final cells = <String>[];
        for (final c in RegExp(r'<a:tc(?:\s[^>]*)?>.*?</a:tc>', dotAll: true)
            .allMatches(r.group(0)!)) {
          final paras = RegExp(r'<a:p(?:\s[^>]*)?>.*?</a:p>', dotAll: true)
              .allMatches(c.group(0)!)
              .map((x) => para(x.group(0)!).replaceAll('\n', ' ').trim())
              .where((t) => t.isNotEmpty);
          cells.add(paras.join(' '));
        }
        rows.add(cells);
      }
      out.writeln();
      out.write(mdTable(rows));
      out.writeln();
    } else {
      out.writeln(para(chunk));
    }
  }
  return out.toString();
}

/// Turns a .docx / .pptx into Markdown text (page break = a line of ---),
/// which the normal Markdown importer then reads.
String officeToMd(List<int> bytes, String ext, List<String> warnings) {
  final parts = readOfficeZip(bytes);
  String md;
  if (ext == 'docx') {
    final doc = parts['word/document.xml'];
    if (doc == null) throw ImportError('No text found in this Word file.');
    md = docxToMd(utf8.decode(doc, allowMalformed: true));
  } else {
    final names = parts.keys
        .where((k) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(k))
        .toList();
    names.sort((a, b) {
      int num(String x) =>
          int.parse(RegExp(r'slide(\d+)\.xml').firstMatch(x)!.group(1)!);
      return num(a).compareTo(num(b));
    });
    if (names.isEmpty) throw ImportError('No slides found in this PowerPoint file.');
    final slides = <String>[];
    var pics = 0;
    for (final n in names) {
      final xml = utf8.decode(parts[n]!, allowMalformed: true);
      pics += RegExp(r'<p:pic>').allMatches(xml).length;
      slides.add(pptxSlideToMd(xml));
    }
    if (pics > 0) warnings.add('$pics picture(s) in the slides were ignored (only text is imported).');
    md = slides.join('\n---\n');
  }
  md = md.replaceFirst(RegExp(r'^(\s*---\s*\n)+'), '');
  return md;
}

// ---------------------------------------------------------------- parsers

ParseResult parseTxt(String text, String rel, int maxChars) {
  final r = ParseResult();
  final lines = text.split('\n');
  var i = 0;
  while (i < lines.length && lines[i].trim().isEmpty) {
    i++;
  }
  final meta = <String, String>{};
  final metaRe = RegExp(r'^\s*@(\w+)\s*:\s*(.*)$');
  while (i < lines.length) {
    final m = metaRe.firstMatch(lines[i]);
    if (m == null) break;
    meta[m.group(1)!.toLowerCase()] = m.group(2)!.trim();
    i++;
  }
  final body = lines.sublist(i).join('\n');
  final pages = buildTextPages(body, maxChars);
  if (pages.isEmpty) {
    r.error = 'The file has no text.';
    return r;
  }
  final problem =
      compareCounts(counts(body), counts(pages.join('\n')), latin: true);
  if (problem != null) {
    r.error = problem;
    return r;
  }
  r.docs.add(Doc(
    pages: List<dynamic>.from(pages),
    src: rel,
    title: meta['title'],
    ar: meta['ar'],
    en: meta['en'],
    category: meta['category'],
    flow: meta['flow'] != 'false',
  ));
  return r;
}

String cleanMd(String l) {
  var s = l
      .replaceAll(_imgRe, '')
      .replaceAllMapped(_linkRe, (m) => m.group(1) ?? '')
      .replaceAll(_commentRe, '');
  s = s.replaceFirst(RegExp(r'^\s{0,3}>\s?'), '');
  s = s.replaceAll('**', '').replaceAll('__', '');
  return s;
}

Map<String, dynamic>? tableBlock(List<String> lines) {
  final rows = <List<String>>[];
  for (final l in lines) {
    var t = l.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    final cells = t.split('|').map((c) => cleanMd(c).trim()).toList();
    final isSep = cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
    if (isSep) continue;
    rows.add(cells);
  }
  if (rows.length < 2) return null;
  if (rows.any((r) => r.length != 2)) return null;
  return {'t': 'table', 'head': rows.first, 'rows': rows.sublist(1)};
}

String unquote(String v) {
  if (v.length >= 2) {
    final f = v[0];
    final l = v[v.length - 1];
    if ((f == '"' || f == "'") && f == l) return v.substring(1, v.length - 1);
  }
  return v;
}

ParseResult parseMd(String text, String rel, int maxChars) {
  final r = ParseResult();
  var body = text;
  final meta = <String, String>{};
  // optional "@title: ..." lines at the very top (also works in Word/PowerPoint)
  {
    final ls = body.split('\n');
    var k = 0;
    while (k < ls.length && ls[k].trim().isEmpty) {
      k++;
    }
    final metaRe2 = RegExp(r'^\s*@(\w+)\s*:\s*(.*)$');
    var found = false;
    while (k < ls.length) {
      final mm = metaRe2.firstMatch(ls[k]);
      if (mm == null) break;
      meta[mm.group(1)!.toLowerCase()] = mm.group(2)!.trim();
      found = true;
      k++;
    }
    if (found) body = ls.sublist(k).join('\n');
  }
  if (body.startsWith('---\n')) {
    final end = body.indexOf('\n---', 3);
    if (end != -1) {
      final fm = end > 4 ? body.substring(4, end) : '';
      for (final l in fm.split('\n')) {
        final idx = l.indexOf(':');
        if (idx > 0) {
          meta[l.substring(0, idx).trim().toLowerCase()] =
              unquote(l.substring(idx + 1).trim());
        }
      }
      final nl = body.indexOf('\n', end + 1);
      body = nl == -1 ? '' : body.substring(nl + 1);
    }
  }

  final pagesBlocks = <List<Map<String, dynamic>>>[];
  var curBlocks = <Map<String, dynamic>>[];
  var pending = <String>[];
  String? headingTitle;
  var sawContent = false;

  void flushText() {
    final t = tidy(pending.join('\n'));
    pending = <String>[];
    if (t.isNotEmpty) curBlocks.add({'t': 'text', 'v': t});
  }

  void closePage() {
    flushText();
    if (curBlocks.isNotEmpty) pagesBlocks.add(curBlocks);
    curBlocks = <Map<String, dynamic>>[];
  }

  final headingRe = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');
  final lines = body.replaceAll('\f', '\n---\n').split('\n');
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (_pageBreak.hasMatch(line)) {
      closePage();
      i++;
      continue;
    }
    if (line.trimLeft().startsWith('|')) {
      final tbl = <String>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
        tbl.add(lines[i]);
        i++;
      }
      final block = tableBlock(tbl);
      if (block != null) {
        flushText();
        curBlocks.add(block);
        sawContent = true;
      } else {
        for (final l in tbl) {
          pending.add(cleanMd(l));
        }
        r.warnings.add('A table that is not 2 columns was kept as plain text.');
      }
      continue;
    }
    if (_imgRe.hasMatch(line)) {
      r.warnings.add('Image links are not imported (skipped).');
    }
    final hm = headingRe.firstMatch(line);
    if (hm != null) {
      final level = hm.group(1)!.length;
      final htxt = cleanMd(hm.group(2)!);
      if (!sawContent && headingTitle == null && level == 1 && meta['title'] == null) {
        headingTitle = htxt;
      } else {
        pending.add(htxt);
        sawContent = true;
      }
      i++;
      continue;
    }
    final cl = cleanMd(line);
    if (cl.trim().isNotEmpty) sawContent = true;
    pending.add(cl);
    i++;
  }
  closePage();

  final pages = <dynamic>[];
  for (final blocks in pagesBlocks) {
    if (blocks.length == 1 && blocks.first['t'] == 'text') {
      pages.addAll(paginateChunk(blocks.first['v'] as String, maxChars));
    } else {
      pages.add({'blocks': blocks});
    }
  }
  if (pages.isEmpty) {
    r.error = 'The file has no text.';
    return r;
  }
  final out = StringBuffer();
  for (final p in pages) {
    out.writeln(plainOfPage(p));
  }
  if (headingTitle != null) out.writeln(headingTitle);
  final problem = compareCounts(counts(body), counts(out.toString()), latin: false);
  if (problem != null) {
    r.error = problem;
    return r;
  }
  r.docs.add(Doc(
    pages: pages,
    src: rel,
    title: meta['title'] ?? headingTitle,
    ar: meta['ar'],
    en: meta['en'],
    category: meta['category'],
    flow: meta['flow'] != 'false',
  ));
  return r;
}

Doc? docFromMap(Map m, String rel, int maxChars, ParseResult r, int n) {
  String? s(String k) {
    final v = m[k];
    return (v is String && v.trim().isNotEmpty) ? v : null;
  }

  final pages = <dynamic>[];
  final raw = m['pages'];
  if (raw is List) {
    for (final p in raw) {
      if (p is String) {
        if (p.trim().isNotEmpty) pages.add(p);
      } else if (p is Map && p['blocks'] is List) {
        pages.add(Map<String, dynamic>.from(p));
      } else {
        r.warnings.add('Entry $n: a page has an unknown format and was skipped.');
      }
    }
  } else if (m['text'] is String) {
    final t = normalizeNl(m['text'] as String);
    pages.addAll(buildTextPages(t, maxChars));
  }
  if (pages.isEmpty) {
    r.warnings.add('Entry $n: no "pages" or "text" - skipped.');
    return null;
  }
  return Doc(
    pages: pages,
    src: rel,
    title: s('title'),
    ar: s('ar'),
    en: s('en'),
    category: s('category'),
    idHint: s('id'),
    flow: m['flow'] == true,
  );
}

ParseResult parseJson(String text, String rel, int maxChars) {
  final r = ParseResult();
  dynamic data;
  try {
    data = jsonDecode(text);
  } on FormatException catch (e) {
    r.error = 'Invalid JSON: ${e.message}';
    return r;
  }
  final List<dynamic> entries;
  if (data is Map && data['items'] is List) {
    entries = data['items'] as List;
    if (data['categories'] is List) {
      for (final c in data['categories'] as List) {
        if (c is Map && c['id'] is String && c['name'] is String) {
          r.categories.add(Map<String, dynamic>.from(c));
        }
      }
    }
  } else if (data is List) {
    entries = data;
  } else if (data is Map) {
    entries = [data];
  } else {
    r.error = 'JSON must be an object or a list of objects.';
    return r;
  }
  var n = 0;
  for (final e in entries) {
    n++;
    if (e is! Map) {
      r.warnings.add('Entry $n is not an object - skipped.');
      continue;
    }
    final d = docFromMap(e, rel, maxChars, r, n);
    if (d != null) r.docs.add(d);
  }
  if (r.docs.isEmpty) {
    r.error = 'No importable entries found in this JSON file.';
    return r;
  }
  final rawC = counts(text);
  final out = StringBuffer();
  for (final d in r.docs) {
    out.writeln(joinPlain(d.pages));
    out.writeln('${d.title ?? ''} ${d.ar ?? ''} ${d.en ?? ''}');
  }
  final outC = counts(out.toString());
  if (rawC[0] > outC[0] || rawC[1] > outC[1]) {
    r.warnings.add('Some Arabic/Malayalam text in this file is in fields the '
        'importer does not use (use "pages" or "text").');
  }
  return r;
}

// ----------------------------------------------------------- library state

late Map<String, dynamic> lib;
late List<Map<String, dynamic>> cats;
late List<Map<String, dynamic>> items;
final Map<String, Map<String, dynamic>> byId = {};
final Map<String, String> existingHashes = {}; // content hash -> item id
Map<String, dynamic> registry = {};

final List<String> rImported = [];
final List<String> rFilled = [];
final List<String> rSkipped = [];
final List<String> rErrors = [];
final List<String> rWarnings = [];
final List<String> rNewCategories = [];

const Map<String, List<String>> kAliases = {
  'quran': ['quran', 'quraan', 'koran', 'surah', 'surahs', 'surat', 'alquran', 'holyquran'],
  'mawlid': ['mawlid', 'mawlids', 'maulid', 'moulid', 'mauled', 'mawlood', 'molid', 'maulidukal', 'mawlidukal'],
  'aurad': ['aurad', 'awrad', 'auraad', 'wird', 'wirds', 'wird'],
  'manaqib': ['manaqib', 'manaqibs', 'manqabath', 'manqabat', 'manaqibu'],
  'baith': ['baith', 'baithukal', 'bait', 'baits', 'abyat'],
  'mala': ['mala', 'malas', 'malappattu', 'malappattukal', 'malapattu'],
  'swalath': ['swalath', 'swalathukal', 'salawat', 'salawath', 'salat', 'salath', 'swalat'],
  'dua': ['dua', 'duas', 'dhua', 'duakal', 'duaa', 'adiya', 'adiyah'],
  'ratib': ['ratib', 'ratibs', 'ratheeb', 'rathib'],
};

const Map<String, Map<String, String>> kPredefined = {
  'aurad': {'name': 'ഔറാദ്', 'ar': 'الأوراد', 'en': 'Aurad'},
  'manaqib': {'name': 'മനാഖിബ്', 'ar': 'المناقب', 'en': 'Manaqib'},
};

String? resolveCategoryId(String raw) {
  final k = keyOf(raw);
  if (k.isEmpty) {
    for (final c in cats) {
      if ((c['ar'] ?? '') == raw || (c['name'] ?? '') == raw) return c['id'] as String;
    }
    return null;
  }
  for (final e in kAliases.entries) {
    if (e.value.contains(k)) return e.key;
  }
  for (final c in cats) {
    if (keyOf(c['id'] as String) == k || keyOf((c['en'] ?? '') as String) == k) {
      return c['id'] as String;
    }
  }
  return null;
}

String prettify(String base) {
  var s = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  final noNum = s.replaceFirst(RegExp(r'^\d+\s*[.)]?\s*'), '');
  if (noNum.isNotEmpty) s = noNum;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

void addCategory(Map<String, dynamic> c) {
  var at = cats.length;
  for (var i = 0; i < cats.length; i++) {
    final t = cats[i]['type'];
    if (t is String && t.isNotEmpty) {
      at = i;
      break;
    }
  }
  cats.insert(at, c);
  rNewCategories.add('${c['id']} (${c['en']})');
}

/// Returns the category id, creating the category when it does not exist.
String ensureCategory(String raw) {
  final known = resolveCategoryId(raw);
  if (known != null) {
    if (!cats.any((c) => c['id'] == known)) {
      final p = kPredefined[known];
      addCategory({
        'id': known,
        'name': p?['name'] ?? prettify(known),
        'ar': p?['ar'] ?? '',
        'en': p?['en'] ?? prettify(known),
      });
    }
    return known;
  }
  var id = keyOf(raw);
  if (id.isEmpty) {
    final h = hashText(raw);
    id = 'x${h.length >= 6 ? h.substring(0, 6) : h}';
  }
  final name = prettify(raw);
  addCategory({'id': id, 'name': name, 'ar': '', 'en': name});
  return id;
}

String newId(String cat, String seed) {
  var slug = seed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) {
    final h = hashText(seed);
    slug = 'x${h.length >= 8 ? h.substring(0, 8) : h}';
  }
  var id = '$cat-$slug';
  var n = 2;
  while (byId.containsKey(id)) {
    id = '$cat-$slug-$n';
    n++;
  }
  return id;
}

int? numberIn(String s, int max) {
  for (final m in RegExp(r'(?<!\d)(\d{1,3})(?!\d)').allMatches(s)) {
    final n = int.parse(m.group(1)!);
    if (n >= 1 && n <= max) return n;
  }
  return null;
}

Map<String, dynamic> findQuranTarget(Doc d, String base, bool juz) {
  final cat = juz ? 'juz' : 'quran';
  final max = juz ? 30 : 114;
  final n = numberIn(base, max) ?? (d.title == null ? null : numberIn(d.title!, max));
  if (n != null) {
    final t = byId['$cat-$n'];
    if (t != null) return t;
  }
  // match by Arabic title
  if (d.ar != null) {
    final k = arKey(d.ar!);
    final hits = items.where((i) => i['category'] == cat && arKey((i['ar'] ?? '') as String) == k).toList();
    if (hits.length == 1) return hits.first;
  }
  // match by English name
  final fk = latinKey(base);
  if (fk.length >= 4) {
    final exact = <Map<String, dynamic>>[];
    final loose = <Map<String, dynamic>>[];
    for (final i in items) {
      if (i['category'] != cat) continue;
      final tk = latinKey(i['title'] as String);
      if (tk.isEmpty) continue;
      if (tk == fk) {
        exact.add(i);
      } else if (tk.contains(fk) || fk.contains(tk)) {
        loose.add(i);
      }
    }
    if (exact.length == 1) return exact.first;
    if (exact.isEmpty && loose.length == 1) return loose.first;
    if (exact.length > 1 || loose.length > 1) {
      throw ImportError('Name matches more than one ${juz ? 'juz' : 'surah'}. '
          'Start the file name with its number, e.g. ${juz ? 'juz-05' : '002-baqarah'}.txt');
    }
  }
  throw ImportError('Could not tell which ${juz ? 'juz (1-30)' : 'surah (1-114)'} this is. '
      'Start the file name with its number, e.g. ${juz ? 'juz-05' : '002-baqarah'}.txt');
}

Map<String, dynamic>? matchPlaceholder(String cat, Doc d, String base) {
  final keys = <String>{latinKey(d.title ?? ''), latinKey(base)}..remove('');
  final ark = d.ar == null ? '' : arKey(d.ar!);
  for (final it in items) {
    if (it['category'] != cat) continue;
    final k = latinKey(it['title'] as String);
    final a = arKey((it['ar'] ?? '') as String);
    if ((k.isNotEmpty && keys.contains(k)) || (ark.isNotEmpty && ark == a)) return it;
  }
  return null;
}

/// Imports one document. Returns the item id, or null when it was skipped.
String? handleDoc(Doc d, String label, List<String> segs, String base, bool dry) {
  String? catId;
  if (d.category != null && d.category!.trim().isNotEmpty) {
    catId = ensureCategory(d.category!.trim());
  } else {
    for (final s in segs) {
      final c = resolveCategoryId(s);
      if (c != null) {
        catId = c;
        break;
      }
    }
    if (catId == null && segs.isNotEmpty) catId = ensureCategory(segs.first);
  }
  if (catId == null) {
    throw ImportError('No category. Put the file inside a category folder '
        '(for example content/mawlid/) or add "@category: mawlid" at the top.');
  }
  final isJuz = catId == 'quran' &&
      (segs.any((s) => keyOf(s).startsWith('juz')) || keyOf(base).startsWith('juz'));
  final hash = contentHash(d.pages);

  Map<String, dynamic>? target;
  if (catId == 'quran') {
    target = findQuranTarget(d, base, isJuz);
  } else if (d.idHint != null && byId.containsKey(d.idHint)) {
    target = byId[d.idHint];
  } else {
    target = matchPlaceholder(catId, d, base);
  }

  final dupId = existingHashes[hash];
  if (target != null) {
    final tp = target['pages'] as List;
    final tid = target['id'] as String;
    if (tp.isNotEmpty) {
      if (dupId == tid) {
        rSkipped.add('$label - already in the library as $tid (identical text)');
      } else {
        rSkipped.add('$label - $tid already has content; existing content kept (not overwritten)');
      }
      return null;
    }
    if (dupId != null) {
      rSkipped.add('$label - same text already exists as $dupId');
      return null;
    }
    target['pages'] = d.pages;
    if (d.flow) target['flow'] = true;
    if (((target['ar'] ?? '') as String).isEmpty && d.ar != null) target['ar'] = d.ar;
    if (((target['en'] ?? '') as String).isEmpty && d.en != null) target['en'] = d.en;
    existingHashes[hash] = tid;
    rFilled.add('$label -> $tid (${d.pages.length} page${d.pages.length == 1 ? '' : 's'})');
    return tid;
  }

  if (dupId != null) {
    rSkipped.add('$label - same text already exists as $dupId');
    return null;
  }
  final title = (d.title != null && d.title!.trim().isNotEmpty) ? d.title!.trim() : prettify(base);
  final id = (d.idHint != null && !byId.containsKey(d.idHint)) ? d.idHint! : newId(catId, latinKey(title).isNotEmpty ? title : base);
  final item = <String, dynamic>{
    'id': id,
    'category': catId,
    'title': title,
    'ar': d.ar ?? '',
    'en': d.en ?? '',
    'pages': d.pages,
  };
  if (d.flow) item['flow'] = true;
  items.add(item);
  byId[id] = item;
  existingHashes[hash] = id;
  rImported.add('$label -> $id [$catId] (${d.pages.length} page${d.pages.length == 1 ? '' : 's'})');
  return id;
}

void processFile(File f, String rel, int maxChars, bool dry) {
  final segs = rel.split('/');
  final fileName = segs.removeLast();
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  if (!['txt', 'md', 'markdown', 'json', 'docx', 'pptx'].contains(ext)) {
    rSkipped.add('$rel - unsupported format (.${ext.isEmpty ? 'none' : ext}). '
        'Save it as .docx, .pptx, .txt, .md or .json');
    return;
  }
  final String text;
  if (ext == 'docx' || ext == 'pptx') {
    final warns = <String>[];
    text = normalizeNl(officeToMd(f.readAsBytesSync(), ext, warns));
    for (final w in warns) {
      rWarnings.add('$rel: $w');
    }
  } else {
    text = normalizeNl(decodeFile(f.readAsBytesSync()));
  }
  final fileHash = hashText(text);
  final reg = registry[rel];
  if (reg is Map && reg['hash'] == fileHash) {
    rSkipped.add('$rel - already imported (file unchanged)');
    return;
  }
  final ParseResult pr;
  if (ext == 'txt') {
    pr = parseTxt(text, rel, maxChars);
  } else if (ext == 'json') {
    pr = parseJson(text, rel, maxChars);
  } else {
    pr = parseMd(text, rel, maxChars);
  }
  if (pr.error != null) throw ImportError(pr.error!);
  for (final w in pr.warnings) {
    rWarnings.add('$rel: $w');
  }
  for (final c in pr.categories) {
    final id = c['id'] as String;
    if (resolveCategoryId(id) == null && !cats.any((x) => x['id'] == id)) {
      addCategory({
        'id': id,
        'name': c['name'],
        'ar': c['ar'] ?? '',
        'en': c['en'] ?? c['name'],
      });
    }
  }
  final ids = <String>[];
  var failed = false;
  for (var k = 0; k < pr.docs.length; k++) {
    final label = pr.docs.length > 1 ? '$rel [#${k + 1}]' : rel;
    try {
      final id = handleDoc(pr.docs[k], label, segs, base, dry);
      if (id != null) ids.add(id);
    } on ImportError catch (e) {
      failed = true;
      rErrors.add('$label: ${e.message}');
    }
  }
  if (!failed) registry[rel] = {'hash': fileHash, 'ids': ids};
}

// -------------------------------------------------------------------- main

void main(List<String> args) {
  final dry = args.contains('--dry-run');
  var maxChars = 1200;
  var contentDir = 'content';
  for (final a in args) {
    if (a.startsWith('--max-chars=')) {
      maxChars = int.tryParse(a.substring('--max-chars='.length)) ?? 1200;
    }
    if (a.startsWith('--content=')) contentDir = a.substring('--content='.length);
  }

  if (!File('pubspec.yaml').existsSync() || !File(kLibraryPath).existsSync()) {
    stderr.writeln('Run this from the project root (the folder with pubspec.yaml) '
        'and make sure $kLibraryPath exists.');
    exit(1);
  }

  lib = jsonDecode(File(kLibraryPath).readAsStringSync()) as Map<String, dynamic>;
  cats = (lib['categories'] as List).cast<Map<String, dynamic>>();
  items = (lib['items'] as List).cast<Map<String, dynamic>>();
  for (final it in items) {
    byId[it['id'] as String] = it;
    final pg = it['pages'] as List;
    if (pg.isNotEmpty) existingHashes[contentHash(pg)] = it['id'] as String;
  }

  final root = Directory(contentDir);
  if (!root.existsSync()) {
    root.createSync(recursive: true);
    for (final f in [
      'quran', 'quran/juz', 'baith', 'mawlid', 'mala', 'swalath', 'dua',
      'ratib', 'aurad', 'manaqib'
    ]) {
      Directory('$contentDir/$f').createSync(recursive: true);
    }
    stdout.writeln('Created the "$contentDir" folder with category sub-folders.');
    stdout.writeln('Put your files inside them, then run this command again.');
    return;
  }

  final regFile = File('$contentDir/$kImportDir/registry.json');
  if (regFile.existsSync()) {
    try {
      final r = jsonDecode(regFile.readAsStringSync());
      if (r is Map<String, dynamic>) registry = r;
    } catch (_) {
      registry = {};
    }
  }

  // collect files
  final entries = <String, File>{};
  for (final e in root.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    var rel = e.path.substring(root.path.length).replaceAll('\\', '/');
    if (rel.startsWith('/')) rel = rel.substring(1);
    final parts = rel.split('/');
    final name = parts.last;
    if (parts.any((p) => p.startsWith('_') || p.startsWith('.'))) continue;
    if (name.startsWith('~\$') || name == 'Thumbs.db' || name == 'desktop.ini') continue;
    entries[rel] = e;
  }
  final rels = entries.keys.toList()..sort();

  stdout.writeln(dry
      ? 'DRY RUN - nothing will be changed.'
      : 'Importing...');
  stdout.writeln('Found ${rels.length} file(s) in "$contentDir".');

  for (final rel in rels) {
    try {
      processFile(entries[rel]!, rel, maxChars, dry);
    } on ImportError catch (e) {
      rErrors.add('$rel: ${e.message}');
    } catch (e) {
      rErrors.add('$rel: unexpected error: $e');
    }
  }

  // ---- report
  final b = StringBuffer();
  final now = DateTime.now();
  b.writeln('IMPORT REPORT  ${now.toIso8601String()}${dry ? '  (dry run)' : ''}');
  b.writeln('================================================');
  b.writeln('Files scanned : ${rels.length}');
  b.writeln('New items     : ${rImported.length}');
  b.writeln('Filled empty  : ${rFilled.length}');
  b.writeln('Skipped       : ${rSkipped.length}');
  b.writeln('Errors        : ${rErrors.length}');
  void section(String title, List<String> list) {
    if (list.isEmpty) return;
    b.writeln('');
    b.writeln('$title (${list.length})');
    b.writeln('------------------------------------------------');
    for (final l in list) {
      b.writeln('  $l');
    }
  }

  section('NEW CATEGORIES', rNewCategories);
  section('IMPORTED AS NEW ITEMS', rImported);
  section('FILLED EXISTING EMPTY ITEMS', rFilled);
  section('SKIPPED', rSkipped);
  section('WARNINGS', rWarnings);
  section('ERRORS', rErrors);

  final perCat = <String, int>{};
  var emptyItems = 0;
  for (final it in items) {
    final c = it['category'] as String;
    if ((it['pages'] as List).isNotEmpty) {
      perCat[c] = (perCat[c] ?? 0) + 1;
    } else {
      emptyItems++;
    }
  }
  b.writeln('');
  b.writeln('ITEMS WITH CONTENT, PER CATEGORY');
  b.writeln('------------------------------------------------');
  for (final e in perCat.entries) {
    final total = items.where((i) => i['category'] == e.key).length;
    b.writeln('  ${e.key.padRight(14)} ${e.value} of $total');
  }
  b.writeln('  (items still empty: $emptyItems)');

  final report = b.toString();
  stdout.write(report);

  if (dry) {
    stdout.writeln('\nDry run finished. Run without --dry-run to apply.');
    return;
  }

  // ---- write (with backup)
  final importDir = Directory('$contentDir/$kImportDir');
  importDir.createSync(recursive: true);
  Directory('${importDir.path}/backups').createSync(recursive: true);
  final stamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
  File(kLibraryPath).copySync('${importDir.path}/backups/library-$stamp.json');

  final changed = rImported.isNotEmpty || rFilled.isNotEmpty || rNewCategories.isNotEmpty;
  if (changed) {
    const enc = JsonEncoder.withIndent('  ');
    File(kLibraryPath).writeAsStringSync(enc.convert(lib));
  }
  File('${importDir.path}/registry.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(registry));
  File('${importDir.path}/import_report.txt').writeAsStringSync(report);

  final index = <Map<String, dynamic>>[];
  for (final it in items) {
    final pg = it['pages'] as List;
    index.add({
      'id': it['id'],
      'category': it['category'],
      'title': it['title'],
      'ar': it['ar'],
      'en': it['en'],
      'pages': pg.length,
      'characters': sig(joinPlain(pg)).length,
      'hasContent': pg.isNotEmpty,
    });
  }
  File('${importDir.path}/content_index.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(index));

  stdout.writeln('\nSaved: $kLibraryPath');
  stdout.writeln('Report: ${importDir.path}/import_report.txt');
  stdout.writeln('Index : ${importDir.path}/content_index.json');
  stdout.writeln('Backup: ${importDir.path}/backups/library-$stamp.json');
  stdout.writeln('Now run:  flutter run -d chrome   (or press R in the running app)');
}
