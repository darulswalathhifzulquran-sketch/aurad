// Removes categories (and all their items) from assets/data/library.json.
//
//   dart tool/remove_categories.dart import samples
//
// A backup is saved in tool/backups first. Also delete the matching folders
// inside content/ (content/import, content/samples), otherwise the importer
// will create them again.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart tool/remove_categories.dart <category-id> [...]');
    exit(2);
  }
  final ids = args.map((a) => a.toLowerCase().trim()).toSet();
  final lib = File('assets/data/library.json');
  if (!lib.existsSync()) {
    stderr.writeln('Run this from the project folder (assets/data/library.json not found).');
    exit(2);
  }
  final data = jsonDecode(utf8.decode(lib.readAsBytesSync())) as Map<String, dynamic>;
  final cats = data['categories'] as List;
  final items = data['items'] as List;

  final removedCats = <String>[];
  cats.removeWhere((c) {
    final m = c as Map;
    final hit = ids.contains((m['id'] ?? '').toString().toLowerCase()) ||
        ids.contains((m['en'] ?? '').toString().toLowerCase());
    if (hit) removedCats.add(m['id'].toString());
    return hit;
  });
  if (removedCats.isEmpty) {
    print('No category found with id/name: ${ids.join(", ")}');
    print('Existing: ${cats.map((c) => (c as Map)['id']).join(", ")}');
    exit(0);
  }
  final removedItems = <String>[];
  items.removeWhere((i) {
    final m = i as Map;
    final hit = removedCats.contains(m['category']);
    if (hit) removedItems.add(m['id'].toString());
    return hit;
  });

  Directory('tool/backups').createSync(recursive: true);
  final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-').substring(0, 19);
  lib.copySync('tool/backups/library-before-remove-$stamp.json');
  lib.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(data));

  final idx = File('assets/data/import_index.json');
  if (idx.existsSync()) {
    final j = jsonDecode(utf8.decode(idx.readAsBytesSync())) as Map<String, dynamic>;
    final files = (j['files'] as Map).cast<String, dynamic>();
    files.removeWhere((k, v) => removedItems.contains((v as Map)['id']));
    j['files'] = files;
    idx.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(j));
  }
  print('Removed categories: ${removedCats.join(", ")}');
  print('Removed items (${removedItems.length}): ${removedItems.join(", ")}');
  print('Backup saved in tool/backups. Now delete the same folders inside content/.');
}
