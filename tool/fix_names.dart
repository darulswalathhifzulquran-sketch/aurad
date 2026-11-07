// One-time fix for the Arabic names:
//   مولد منقوص  ->  منقوص مولد      (Mawlid folder)
//   مالا محيي الدين -> محيي الدين مالا  (Mala folder)
//   دعاء الكرب  ->  الكرب دعاء       (Dua folder, names that start with دعاء)
// It also removes the empty Aurad / Manaqib categories.
// Run from the project root:   dart tool/fix_names.dart
// A backup of library.json is saved first. Running it twice changes nothing.
import 'dart:convert';
import 'dart:io';

const String kLibraryPath = 'assets/data/library.json';

// category id -> the first word that must move to the end
const Map<String, String> kMove = {
  'mawlid': 'مولد',
  'mala': 'مالا',
  'dua': 'دعاء',
};

void main() {
  final f = File(kLibraryPath);
  if (!f.existsSync()) {
    stderr.writeln('Run this from the project root (folder with pubspec.yaml).');
    exit(1);
  }
  final lib = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final cats = (lib['categories'] as List).cast<Map<String, dynamic>>();
  final items = (lib['items'] as List).cast<Map<String, dynamic>>();

  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
  final backup = '$kLibraryPath.backup-$stamp';
  f.copySync(backup);

  var renamed = 0;
  for (final it in items) {
    final first = kMove[it['category']];
    if (first == null) continue;
    final ar = ((it['ar'] ?? '') as String).trim();
    final prefix = '$first ';
    if (ar.startsWith(prefix) && ar.length > prefix.length) {
      final rest = ar.substring(prefix.length).trim();
      it['ar'] = '$rest $first';
      stdout.writeln('  $ar  ->  ${it['ar']}');
      renamed++;
    }
  }

  var removed = 0;
  for (final id in ['aurad', 'manaqib']) {
    final has = items.any((i) => i['category'] == id);
    if (!has) {
      final before = cats.length;
      cats.removeWhere((c) => c['id'] == id);
      removed += before - cats.length;
    } else {
      stdout.writeln('  "$id" has items, so the category was kept.');
    }
  }

  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lib));
  stdout.writeln('Renamed: $renamed   Categories removed: $removed');
  stdout.writeln('Backup: $backup');
  stdout.writeln('Now press R in the running app, or run: flutter run -d chrome');
}
