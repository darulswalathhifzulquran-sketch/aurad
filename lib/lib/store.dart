import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

late AppState app;

const String kArabicFont = 'ArabicFont';
const List<String> kFontFallback = [
  'Amiri',
  'Noto Naskh Arabic',
  'Traditional Arabic',
  'Arial'
];
const String kAppName = 'رياض الأذكار';

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  final List<Category> categories;
  final List<Item> items;

  bool dark;
  double zoom;
  Set<String> bookmarks;
  int counter;
  int target;

  AppState._(this.prefs, this.categories, this.items)
      : dark = prefs.getBool('dark') ?? false,
        zoom = prefs.getDouble('zoom') ?? 1.0,
        bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet(),
        counter = prefs.getInt('counter') ?? 0,
        target = prefs.getInt('target') ?? 33;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('assets/data/library.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final cats = (map['categories'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
    final items = (map['items'] as List)
        .map((e) => Item.fromJson(e as Map<String, dynamic>))
        .toList();
    // Categories that must never show up (created by mistake by the importer).
    final hidden = cats
        .where((c) =>
            kHiddenCategories.contains(c.id.toLowerCase()) ||
            kHiddenCategories.contains(c.en.toLowerCase()))
        .map((c) => c.id)
        .toSet();
    cats.removeWhere((c) => hidden.contains(c.id));
    items.removeWhere((i) => hidden.contains(i.category));
    await loadQuran(items);
    await loadMushaf();
    await loadMajlis(items);
    await loadExtras(items);
    fixArabicNames(items);
    return AppState._(prefs, cats, items);
  }

  List<Item> itemsIn(String categoryId) =>
      items.where((i) => i.category == categoryId).toList();

  void toggleDark() {
    dark = !dark;
    prefs.setBool('dark', dark);
    notifyListeners();
  }

  void setZoom(double v) {
    zoom = v.clamp(1.0, 2.5).toDouble();
    prefs.setDouble('zoom', zoom);
    notifyListeners();
  }

  void incCounter() {
    if (counter < 99999) counter++;
    prefs.setInt('counter', counter);
    notifyListeners();
  }

  void undoCounter() {
    if (counter > 0) counter--;
    prefs.setInt('counter', counter);
    notifyListeners();
  }

  void setTarget(int t) {
    target = t;
    prefs.setInt('target', t);
    notifyListeners();
  }

  void resetCounter() {
    counter = 0;
    prefs.setInt('counter', counter);
    notifyListeners();
  }

  bool isBookmarked(String id) => bookmarks.contains(id);

  void toggleBookmark(String id) {
    bookmarks.contains(id) ? bookmarks.remove(id) : bookmarks.add(id);
    prefs.setStringList('bookmarks', bookmarks.toList());
    notifyListeners();
  }
}

/// Removes Arabic diacritics and lowercases, so search works without harakat.
String normalize(String s) =>
    s.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '').toLowerCase();


// ---------------------------------------------------------------------------
// Holy Qur'an: built from assets/data/quran.txt (Tanzil Uthmani text,
// lines like  2|255|text ). If the file is missing the Qur'an items simply
// stay empty (hourglass), the rest of the app works as before.
// ---------------------------------------------------------------------------

// [surah, ayah] where each juz starts (Madani mushaf).
const List<List<int>> kJuzStart = [
  [1, 1], [2, 142], [2, 253], [3, 93], [4, 24], [4, 148], [5, 82], [6, 111],
  [7, 88], [8, 41], [9, 93], [11, 6], [12, 53], [15, 1], [17, 1], [18, 75],
  [21, 1], [23, 1], [25, 21], [27, 56], [29, 46], [33, 31], [36, 28],
  [39, 32], [41, 47], [46, 1], [51, 31], [58, 1], [67, 1], [78, 1],
];

const int kQuranPageWords = 75; // roughly how many words fit one page
const String kBasmala = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

String _arDigits(int n) => n
    .toString()
    .split('')
    .map((c) => String.fromCharCode(0x0660 + int.parse(c)))
    .join();

String _bare(String w) =>
    w.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '');

/// Shown instead of "Content not added yet" on Qur'an pages when loading fails.
String quranStatus = '';

const List<String> kQuranFiles = [
  'assets/data/quran.txt',
  'assets/data/quran-uthmani.txt',
  'assets/data/quran_uthmani.txt',
  'assets/data/Quran.txt',
  'assets/data/quran.txt.txt',
  'assets/data/quran-uthmani.txt.txt',
];

Future<void> loadQuran(List<Item> items) async {
  String? raw;
  for (final f in kQuranFiles) {
    try {
      raw = await rootBundle.loadString(f);
      break;
    } catch (_) {}
  }
  if (raw == null) {
    quranStatus = 'Qur\'an file NOT FOUND.\n'
        'Save the Tanzil file as  assets/data/quran.txt  (check it is not '
        'quran.txt.txt), make sure pubspec.yaml has  - assets/data/  then run '
        'flutter pub get, stop the app (q) and run flutter run -d chrome again.';
    return;
  }
  if (raw.startsWith('\uFEFF')) raw = raw.substring(1);
  // verses[surah] = list of ayah texts (index 0 = ayah 1)
  final verses = <int, List<String>>{};
  for (final line in raw.split('\n')) {
    final l = line.trim();
    if (l.isEmpty || l.startsWith('#')) continue;
    final a = l.indexOf('|');
    final b = a < 0 ? -1 : l.indexOf('|', a + 1);
    if (a < 0 || b < 0) continue;
    final sNo = int.tryParse(l.substring(0, a));
    final vNo = int.tryParse(l.substring(a + 1, b));
    if (sNo == null || vNo == null) continue;
    var t = l.substring(b + 1).trim();
    // Some files put the Basmala in front of ayah 1: remove it, the header adds it.
    if (vNo == 1 && sNo != 1 && sNo != 9) {
      final w = t.split(' ');
      if (w.length > 4 && _bare(w[0]) == 'بسم') t = w.sublist(4).join(' ');
    }
    (verses[sNo] ??= []).add(t);
  }
  if (verses.length < 114) {
    quranStatus = 'Qur\'an file found but only ${verses.length} surahs could be '
        'read (need 114). Download it again from tanzil.net as '
        '"Text (with aya numbers)", Uthmani.';
    return;
  }

  final names = <int, String>{};
  for (final it in items.where((i) => i.category == 'quran')) {
    final n = int.tryParse(it.id.split('-').last);
    if (n != null) names[n] = it.ar;
  }

  List<PageData> build(int fs, int fa, int ts, int ta) {
    // from (fs:fa) up to and including (ts:ta)
    final pages = <PageData>[];
    var blocks = <Block>[];
    var text = StringBuffer();
    var words = 0;

    void flushText() {
      if (text.isNotEmpty) {
        blocks.add(Block(type: 'text', text: text.toString().trim()));
        text = StringBuffer();
      }
    }

    void flushPage() {
      flushText();
      if (blocks.isNotEmpty) pages.add(PageData(blocks));
      blocks = <Block>[];
      words = 0;
    }

    void addChunk(String chunk, int w) {
      if (words > 0 && words + w > kQuranPageWords) {
        if (words >= kQuranPageWords * 0.55) {
          flushPage();
        }
      }
      text.write(chunk);
      words += w;
    }

    for (var s = fs; s <= ts; s++) {
      final list = verses[s]!;
      final first = s == fs ? fa : 1;
      final last = s == ts ? ta : list.length;
      for (var v = first; v <= last; v++) {
        if (v == 1) {
          flushText();
          blocks.add(Block(type: 'center', text: names[s] ?? 'سورة $s'));
          if (s != 1 && s != 9) {
            blocks.add(Block(type: 'center', text: kBasmala));
          }
          words += 14;
        }
        final marker = ' \uFD3F${_arDigits(v)}\uFD3E ';
        final ws = list[v - 1].split(' ');
        if (ws.length > 110) {
          // very long ayah (2:282): cut into pieces
          for (var i = 0; i < ws.length; i += 70) {
            final end = i + 70 < ws.length ? i + 70 : ws.length;
            final isLast = end == ws.length;
            addChunk(
                '${ws.sublist(i, end).join(' ')}${isLast ? marker : ' '}',
                end - i);
          }
        } else {
          addChunk('${list[v - 1]}$marker', ws.length);
        }
      }
    }
    flushPage();
    return pages;
  }

  for (final it in items) {
    final n = int.tryParse(it.id.split('-').last);
    if (n == null) continue;
    if (it.category == 'quran' && verses.containsKey(n)) {
      it.setPages(build(n, 1, n, verses[n]!.length));
    } else if (it.category == 'juz' && n >= 1 && n <= 30) {
      final st = kJuzStart[n - 1];
      int es, ea;
      if (n == 30) {
        es = 114;
        ea = verses[114]!.length;
      } else {
        final nx = kJuzStart[n];
        if (nx[1] == 1) {
          es = nx[0] - 1;
          ea = verses[es]!.length;
        } else {
          es = nx[0];
          ea = nx[1] - 1;
        }
      }
      it.setPages(build(st[0], st[1], es, ea));
    }
  }
}


// ---------------------------------------------------------------------------
// Hidden categories, Madinah Mushaf page images, Majlisunnoor book pages
// ---------------------------------------------------------------------------
const Set<String> kHiddenCategories = {'import', 'samples'};

/// True when assets/quran/info.json exists (pages were made by
/// tool/pdf_to_pages.py). Then Surah / Juz open the Mushaf page viewer.
bool mushafReady = false;
int mushafCount = 604;
String mushafExt = 'jpg'; // picture type, set by info.json ("ext")

Future<void> loadMushaf() async {
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/quran/info.json'))
        as Map<String, dynamic>;
    mushafCount = (j['count'] as num).toInt();
    mushafExt = (j['ext'] ?? 'jpg').toString();
    mushafReady = mushafCount > 0;
  } catch (_) {
    mushafReady = false;
  }
}

/// Majlisunnoor: page pictures (assets/majlis/001.jpg ...) shown inside the
/// same gold border page with the "Majlis Swalath Sa'adah" label.
Future<void> loadMajlis(List<Item> items) async {
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/majlis/info.json'))
        as Map<String, dynamic>;
    final n = (j['count'] as num).toInt();
    final aspect = (j['aspect'] as num).toDouble();
    final ext = (j['ext'] ?? 'jpg').toString();
    if (n <= 0) return;
    items.removeWhere((i) => i.id == 'majlisunnoor-book');
    items.add(Item(
      id: 'majlisunnoor-book',
      category: 'majlisunnoor',
      title: 'Majlisunnoor',
      ar: 'مجلس النور',
      en: 'Majlisunnoor',
      pages: [
        for (var p = 1; p <= n; p++)
          PageData([
            Block(
              type: 'image',
              asset: 'assets/majlis/${p.toString().padLeft(3, '0')}.$ext',
              aspect: aspect,
              wf: 1.0,
            )
          ])
      ],
    ));
  } catch (_) {}
}


// ---------------------------------------------------------------------------
// Extra items (assets/data/extra_items.json): page pictures for Majlisunnoor,
// Haddad Ratib, the three Malas, text for Swalathus Sa'adha.
// An entry fills an existing item of the same category when one of its
// "match" words is found in the item's id / title / Arabic name. Items that
// already have content are left alone (unless the entry says "replace").
// ---------------------------------------------------------------------------
Future<void> loadExtras(List<Item> items) async {
  List list;
  try {
    list = jsonDecode(await rootBundle.loadString('assets/data/extra_items.json'))
        as List;
  } catch (_) {
    return;
  }
  for (final e in list) {
    try {
      final m = e as Map<String, dynamic>;
      final cat = m['category'] as String;
      final id = m['id'] as String;
      final pages =
          (m['pages'] as List).map((p) => PageData.fromJson(p)).toList();
      final match =
          ((m['match'] ?? []) as List).map((x) => x.toString().toLowerCase());
      Item? target;
      for (final it in items) {
        if (it.category != cat) continue;
        final hay = '${it.id} ${it.title} ${it.en} ${it.ar}'.toLowerCase();
        if (it.id == id || match.any((x) => hay.contains(x))) {
          target = it;
          break;
        }
      }
      if (target != null) {
        if (!target.hasContent || m['replace'] == true) target.setPages(pages);
      } else {
        items.add(Item(
          id: id,
          category: cat,
          title: m['title'] as String,
          ar: (m['ar'] ?? '') as String,
          en: (m['en'] ?? '') as String,
          pages: pages,
        ));
      }
    } catch (_) {}
  }
}

/// Arabic names are written "<name> مولد" and "<name> مالا".
void fixArabicNames(List<Item> items) {
  String fix(String ar, String word) {
    final a = ar.trim();
    if (a.isEmpty) return a;
    if (a.startsWith('$word ')) return '${a.substring(word.length + 1)} $word';
    if (a.endsWith(' $word') || a == word) return a;
    return '$a $word';
  }

  for (final it in items) {
    if (it.category == 'mawlid') {
      it.ar = fix(it.ar, '\u0645\u0648\u0644\u062f');
    } else if (it.category == 'mala') {
      it.ar = fix(it.ar, '\u0645\u0627\u0644\u0627');
    }
  }
}
