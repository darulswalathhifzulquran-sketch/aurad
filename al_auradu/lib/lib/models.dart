class Category {
  final String id;
  final String name; // Malayalam
  String ar; // Arabic
  final String en; // English
  final String type; // '' (folder) or 'pdf'
  final String pdf; // link to open when type == 'pdf'
  Category(
      {required this.id,
      required this.name,
      required this.ar,
      required this.en,
      this.type = '',
      this.pdf = ''});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        ar: j['ar'] ?? '',
        en: j['en'] ?? '',
        type: j['type'] ?? '',
        pdf: j['pdf'] ?? '',
      );
}

/// One block of a page: plain text, or a bordered 2-column table.
class Block {
  final String type; // 'text' | 'table'
  final String text;
  final List<String> head;
  final List<List<String>> rows;
  // image block
  final String asset;
  final double aspect; // width / height
  final double wf; // width as a fraction of the text width
  final bool tint; // dark mode: draw the picture in white
  final double ts; // table font scale (0 = work it out)
  Block(
      {required this.type,
      this.text = '',
      this.head = const [],
      this.rows = const [],
      this.asset = '',
      this.aspect = 1,
      this.wf = 0.5,
      this.tint = false,
      this.ts = 0});

  factory Block.fromJson(Map<String, dynamic> j) => Block(
        type: (j['t'] ?? 'text') as String,
        text: (j['v'] ?? '') as String,
        head: ((j['head'] ?? []) as List).map((e) => e.toString()).toList(),
        rows: ((j['rows'] ?? []) as List)
            .map((r) => (r as List).map((e) => e.toString()).toList())
            .toList(),
        asset: (j['asset'] ?? '') as String,
        aspect: ((j['aspect'] ?? 1) as num).toDouble(),
        wf: ((j['wf'] ?? 0.5) as num).toDouble(),
        tint: (j['tint'] ?? false) as bool,
      );

  String get plain => (type == 'text' || type == 'center')
      ? text
      : type == 'image'
          ? ''
          : [...head, ...rows.expand((r) => r)].join(' ');
}

class PageData {
  final List<Block> blocks;
  PageData(this.blocks);

  factory PageData.fromJson(dynamic e) {
    if (e is String) return PageData([Block(type: 'text', text: e)]);
    final m = e as Map<String, dynamic>;
    return PageData((m['blocks'] as List)
        .map((b) => Block.fromJson(b as Map<String, dynamic>))
        .toList());
  }

  String get plain => blocks.map((b) => b.plain).join(' ');
}

class Item {
  final String id;
  final String category;
  final String title; // English letters (Manglish)
  String ar; // Arabic
  final String en;
  List<PageData> pages;
  String? _norm;
  /// Normalised search text, computed once (Qur'an items are big).
  String searchNorm(String Function(String) f) => _norm ??= f(searchText);
  Item({
    required this.id,
    required this.category,
    required this.title,
    required this.ar,
    required this.en,
    required this.pages,
  });

  void setPages(List<PageData> p) {
    pages = p;
    _norm = null;
  }

  bool get hasContent => pages.isNotEmpty;
  String get searchText => pages.map((p) => p.plain).join(' ');

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        category: j['category'],
        title: j['title'],
        ar: j['ar'] ?? '',
        en: j['en'] ?? '',
        pages: (j['pages'] as List).map((e) => PageData.fromJson(e)).toList(),
      );
}
