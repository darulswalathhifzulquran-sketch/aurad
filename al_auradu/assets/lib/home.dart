import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'store.dart';
import 'folder.dart';
import 'counter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String query = '';

  IconData iconFor(String id) {
    switch (id) {
      case 'quran':
        return Icons.menu_book;
      case 'baith':
        return Icons.notes;
      case 'mawlid':
        return Icons.mosque;
      case 'mala':
        return Icons.queue_music;
      case 'swalath':
        return Icons.favorite;
      case 'dua':
        return Icons.pan_tool;
      case 'ratib':
        return Icons.repeat;
      case 'majlisunnoor':
        return Icons.picture_as_pdf;
      case 'counter':
        return Icons.touch_app;
      default:
        return Icons.folder;
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> openCategory(Category cat) async {
    if (cat.type == 'counter') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CounterScreen()),
      );
      return;
    }
    if (cat.type == 'pdf') {
      if (app.itemsIn(cat.id).isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FolderScreen(category: cat)),
        );
        return;
      }
      if (cat.pdf.isEmpty) {
        _msg('PDF not added yet');
        return;
      }
      final ok = await launchUrl(Uri.parse(cat.pdf),
          mode: LaunchMode.externalApplication);
      if (!ok && mounted) _msg('Could not open the PDF');
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FolderScreen(category: cat)),
    );
  }

  List<Item> get searchResults {
    final q = normalize(query.trim());
    return app.items.where((i) {
      return normalize(i.title).contains(q) ||
          normalize(i.ar).contains(q) ||
          normalize(i.en).contains(q) ||
          i.searchNorm(normalize).contains(q);
    }).toList();
  }

  Widget folderGrid() {
    return LayoutBuilder(builder: (context, c) {
      const pad = 12.0;
      const gap = 12.0;
      const cols = 3;
      final n = app.categories.length;
      final rows = (n / cols).ceil();
      final cw = (c.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
      var ch = (c.maxHeight - pad * 2 - gap * (rows - 1)) / rows;
      if (ch < 120) ch = 120;
      if (ch > cw * 1.4) ch = cw * 1.4;
      final base = cw < ch ? cw : ch;
      double sz(double f, double lo, double hi) =>
          (base * f).clamp(lo, hi).toDouble();
      return GridView.builder(
        padding: const EdgeInsets.all(pad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: cw / ch,
        ),
        itemCount: n,
        itemBuilder: (context, i) {
          final cat = app.categories[i];
          final count = (cat.type == 'pdf' && app.itemsIn(cat.id).isEmpty)
              ? 'PDF'
              : (cat.type == 'counter'
                  ? '${app.counter}'
                  : '${app.itemsIn(cat.id).length}');
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openCategory(cat),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconFor(cat.id), size: sz(0.26, 22, 64)),
                        const SizedBox(height: 2),
                        Text(cat.ar,
                            style: TextStyle(
                                fontFamily: kArabicFont,
                                fontFamilyFallback: kFontFallback,
                                fontSize: sz(0.2, 16, 44))),
                        Text(cat.name,
                            style: TextStyle(fontSize: sz(0.11, 11, 22))),
                        Text(cat.en,
                            style: TextStyle(fontSize: sz(0.09, 10, 18))),
                        Text(count,
                            style: TextStyle(
                                fontSize: sz(0.08, 10, 16),
                                color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget list(List<Item> items, String emptyText) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => itemTile(context, items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        Widget body;
        if (tab == 1) {
          body = list(
              app.items.where((i) => app.isBookmarked(i.id)).toList(),
              'No bookmarks yet');
        } else {
          body = Column(
            children: [
              SwitchListTile(
                dense: true,
                secondary: Icon(app.dark ? Icons.dark_mode : Icons.light_mode),
                title: const Text('Dark mode'),
                value: app.dark,
                onChanged: (_) => app.toggleDark(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28)),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Expanded(
                child: query.trim().isEmpty
                    ? folderGrid()
                    : list(searchResults, 'Nothing found'),
              ),
            ],
          );
        }
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text(kAppName,
                style: TextStyle(
                    fontFamily: kArabicFont,
                    fontFamilyFallback: kFontFallback,
                    fontSize: 30)),
            actions: [
              IconButton(
                tooltip: 'Dark mode',
                icon: Icon(app.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: app.toggleDark,
              ),
            ],
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Library'),
              NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Bookmarks'),
            ],
          ),
        );
      },
    );
  }
}
