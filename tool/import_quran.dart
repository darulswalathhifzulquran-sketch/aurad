// Fills the 114 surahs of assets/data/library.json from a Quran text file.
//
// SOURCE: the Tanzil project text (tanzil.net) - one verse per line:
//         surah|ayah|text          (lines starting with # are ignored)
// Put it at   content/_source/quran-uthmani.txt   (or use --file=...)
//
// Run from the project root (folder with pubspec.yaml):
//     dart tool/import_quran.dart --dry-run     (checks only, changes nothing)
//     dart tool/import_quran.dart               (writes library.json)
//
// SAFETY
//  * The file is checked BEFORE anything is written: 114 surahs, 6236 verses,
//    and the verse count of every surah must match the standard count.
//  * Verses are never split, edited, re-ordered or "corrected".
//  * After the pages are built they are read back and compared with the
//    source text, verse by verse. Any difference cancels the import.
//  * A surah that already has pages is left untouched.
//  * library.json is backed up first (content/_import/backups/).
import 'dart:convert';
import 'dart:io';

const String kLibraryPath = 'assets/data/library.json';
const String kDefaultSource = 'content/_source/quran-uthmani.txt';
const String kImportDir = 'content/_import';

/// Number of verses in each of the 114 surahs (sum = 6236).
const List<int> kAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111,
  110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45,
  83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55,
  78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20,
  56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21,
  11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
];

final RegExp _marks = RegExp(r'[ً-ٰٟۖ-ۭـ]');
final RegExp _ayahMarker = RegExp(r'\s*﴾([٠-٩]+)﴿\s*');

String plainAr(String s) => s
    .replaceAll(_marks, '')
    .replaceAll('ٱ', 'ا')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String arabicDigits(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => c - 48 + 0x0660));

int fromArabicDigits(String s) =>
    int.parse(String.fromCharCodes(s.codeUnits.map((c) => c - 0x0660 + 48)));

String decodeFile(List<int> bytes) {
  try {
    final s = utf8.decode(bytes);
    return (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) ? s.substring(1) : s;
  } on FormatException {
    stderr.writeln('The source file is not UTF-8. Download it again from Tanzil '
        '(encoding UTF-8).');
    exit(2);
  }
}

String surahName(int s) => 'surah $s';

void main(List<String> args) {
  final dry = args.contains('--dry-run');
  final noBasmala = args.contains('--no-basmala');
  var maxChars = 650;
  var sourcePath = kDefaultSource;
  for (final a in args) {
    if (a.startsWith('--max-chars=')) {
      maxChars = int.tryParse(a.substring('--max-chars='.length)) ?? 650;
    }
    if (a.startsWith('--file=')) sourcePath = a.substring('--file='.length);
  }

  if (!File('pubspec.yaml').existsSync() || !File(kLibraryPath).existsSync()) {
    stderr.writeln('Run this from the project root (the folder with pubspec.yaml).');
    exit(1);
  }
  final srcFile = File(sourcePath);
  if (!srcFile.existsSync()) {
    stderr.writeln('Quran text file not found: $sourcePath');
    stderr.writeln('1. Open https://tanzil.net/download/');
    stderr.writeln('2. Quran Text Type: Uthmani   Output: Text (with aya numbers)');
    stderr.writeln('3. Save the file as: $kDefaultSource');
    exit(1);
  }

  final errors = <String>[];
  final warnings = <String>[];

  // ---------------------------------------------------------- 1. parse
  final src = <int, Map<int, String>>{};
  final lines = decodeFile(srcFile.readAsBytesSync())
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  var lineNo = 0;
  for (final raw in lines) {
    lineNo++;
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final i1 = line.indexOf('|');
    final i2 = i1 < 0 ? -1 : line.indexOf('|', i1 + 1);
    final s = i1 > 0 ? int.tryParse(line.substring(0, i1).trim()) : null;
    final a = i2 > 0 ? int.tryParse(line.substring(i1 + 1, i2).trim()) : null;
    if (s == null || a == null) {
      warnings.add('Line $lineNo is not in "surah|ayah|text" form and was ignored.');
      continue;
    }
    final text = line.substring(i2 + 1).trim();
    final m = src.putIfAbsent(s, () => <int, String>{});
    if (m.containsKey(a)) {
      errors.add('Surah $s ayah $a appears twice (line $lineNo).');
      continue;
    }
    m[a] = text;
  }

  // ---------------------------------------------------------- 2. validate
  var total = 0;
  for (var s = 1; s <= 114; s++) {
    final m = src[s];
    if (m == null) {
      errors.add('Surah $s is missing in the source file.');
      continue;
    }
    final want = kAyahCounts[s - 1];
    if (m.length != want) {
      errors.add('Surah $s has ${m.length} verses in the file, expected $want.');
    }
    for (var a = 1; a <= want; a++) {
      final t = m[a];
      if (t == null) {
        errors.add('Surah $s ayah $a is missing.');
      } else if (t.isEmpty) {
        errors.add('Surah $s ayah $a is empty.');
      } else if (t.contains('﴾') || t.contains('﴿')) {
        errors.add('Surah $s ayah $a contains a verse bracket character.');
      }
    }
    total += m.length;
  }
  for (final s in src.keys) {
    if (s < 1 || s > 114) errors.add('Unknown surah number $s in the file.');
  }
  if (total != 6236 && errors.isEmpty) {
    errors.add('Total verses are $total, expected 6236.');
  }

  // ---------------------------------------------------------- 3. build pages
  final pagesOf = <int, List<String>>{};
  String basmala = '';
  if (errors.isEmpty) {
    basmala = src[1]![1]!;
    final basmalaWords = plainAr(basmala);
    for (var s = 1; s <= 114; s++) {
      final ay = Map<int, String>.from(src[s]!);
      // Some sources glue the Bismillah in front of verse 1. Take it off
      // (it is shown once as a heading instead of being repeated).
      if (s != 1 && s != 9) {
        final words = ay[1]!.split(RegExp(r'\s+'));
        final n = basmalaWords.split(' ').length;
        if (words.length > n && plainAr(words.take(n).join(' ')) == basmalaWords) {
          ay[1] = words.skip(n).join(' ');
          warnings.add('Surah $s: the Bismillah was removed from the front of verse 1.');
        }
      }
      src[s] = ay;
      final withHeader = !noBasmala && s != 1 && s != 9;
      final pages = <String>[];
      var buf = StringBuffer();
      var len = 0;
      var hasAyah = false;
      void flush() {
        final t = buf.toString().trim();
        if (t.isNotEmpty) pages.add(t);
        buf = StringBuffer();
        len = 0;
        hasAyah = false;
      }

      if (withHeader) {
        buf.write(basmala);
        buf.write('\n');
        len = basmala.length + 1;
      }
      for (var a = 1; a <= kAyahCounts[s - 1]; a++) {
        final piece = '${ay[a]} ﴾${arabicDigits(a)}﴿';
        if (hasAyah && len + piece.length + 1 > maxChars) flush();
        buf.write(piece);
        buf.write(' ');
        len += piece.length + 1;
        hasAyah = true;
      }
      flush();
      pagesOf[s] = pages;
    }

    // ------------------------------------------------------ 4. read back
    for (var s = 1; s <= 114; s++) {
      var all = pagesOf[s]!.join(' ');
      final withHeader = !noBasmala && s != 1 && s != 9;
      if (withHeader) {
        if (!all.startsWith(basmala)) {
          errors.add('Surah $s: check failed (heading).');
          continue;
        }
        all = all.substring(basmala.length);
      }
      final nums = _ayahMarker.allMatches(all).map((m) => fromArabicDigits(m.group(1)!)).toList();
      final texts = all.split(_ayahMarker).map((t) => t.trim()).toList();
      if (texts.isNotEmpty && texts.last.isEmpty) texts.removeLast();
      final want = kAyahCounts[s - 1];
      if (nums.length != want || texts.length != want) {
        errors.add('Surah $s: read-back found ${texts.length} verses, expected $want.');
        continue;
      }
      for (var a = 1; a <= want; a++) {
        if (nums[a - 1] != a) {
          errors.add('Surah $s: verse number $a is out of order in the pages.');
          break;
        }
        if (texts[a - 1] != src[s]![a]) {
          errors.add('Surah $s ayah $a: text differs from the source after paging.');
          break;
        }
      }
    }
  }

  // ---------------------------------------------------------- 5. library
  final lib = jsonDecode(File(kLibraryPath).readAsStringSync()) as Map<String, dynamic>;
  final items = (lib['items'] as List).cast<Map<String, dynamic>>();
  final filled = <int>[];
  final kept = <int>[];
  if (errors.isEmpty) {
    for (var s = 1; s <= 114; s++) {
      final idx = items.indexWhere((i) => i['id'] == 'quran-$s');
      if (idx < 0) {
        errors.add('The library has no item "quran-$s" (${surahName(s)}).');
        continue;
      }
      final it = items[idx];
      if ((it['pages'] as List).isNotEmpty) {
        kept.add(s);
      } else {
        it['pages'] = pagesOf[s];
        filled.add(s);
      }
    }
  }

  // ---------------------------------------------------------- report
  final b = StringBuffer();
  final now = DateTime.now();
  b.writeln('QURAN IMPORT REPORT  ${now.toIso8601String()}${dry ? '  (dry run)' : ''}');
  b.writeln('Source file : $sourcePath');
  b.writeln('Surahs found: ${src.length}   Verses: $total');
  if (errors.isEmpty) {
    var pageCount = 0;
    pagesOf.forEach((_, v) => pageCount += v.length);
    b.writeln('All checks passed: 114 surahs, 6236 verses, read-back identical.');
    b.writeln('Surahs filled        : ${filled.length}');
    b.writeln('Surahs kept as they were (already had content): ${kept.length}'
        '${kept.isEmpty ? '' : '  -> ${kept.join(', ')}'}');
    b.writeln('Pages created        : $pageCount');
  }
  if (warnings.isNotEmpty) {
    b.writeln('\nWARNINGS (${warnings.length})');
    for (final w in warnings.take(60)) {
      b.writeln('  $w');
    }
  }
  if (errors.isNotEmpty) {
    b.writeln('\nERRORS (${errors.length}) - NOTHING WAS CHANGED');
    for (final e in errors.take(100)) {
      b.writeln('  $e');
    }
  }
  stdout.write(b.toString());

  if (errors.isNotEmpty) {
    if (!dry) _saveReport(b.toString());
    exit(2);
  }
  if (dry) {
    stdout.writeln('\nDry run finished. Run without --dry-run to write library.json.');
    return;
  }
  if (filled.isEmpty) {
    _saveReport(b.toString());
    stdout.writeln('\nNothing to do.');
    return;
  }

  // ---------------------------------------------------------- write
  Directory('$kImportDir/backups').createSync(recursive: true);
  final stamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
  final backup = '$kImportDir/backups/library-before-quran-$stamp.json';
  File(kLibraryPath).copySync(backup);
  File(kLibraryPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lib));
  _saveReport(b.toString());
  stdout.writeln('\nSaved: $kLibraryPath');
  stdout.writeln('Backup: $backup');
  stdout.writeln('Report: $kImportDir/quran_report.txt');
  stdout.writeln('Now run:  flutter run -d chrome   (or press R / restart the app)');
}

void _saveReport(String text) {
  Directory(kImportDir).createSync(recursive: true);
  File('$kImportDir/quran_report.txt').writeAsStringSync(text);
}
