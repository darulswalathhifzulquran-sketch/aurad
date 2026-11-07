import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'models.dart';
import 'store.dart';
import 'folder.dart';
import 'reader.dart';
import 'counter.dart';
import 'reference_home.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  Widget folderIcon(String id, double size) {
    const imageByFolderId = {
      'quran': 'assets/images/quran.png',
      'baith': 'assets/images/baith.png',
      'mawlid': 'assets/images/mawlid.png',
      'mala': 'assets/images/mala.png',
      'swalath': 'assets/images/swalath.png',
      'dua': 'assets/images/dua.png',
      'ratib': 'assets/images/ratib.png',
      'majlisunnoor': 'assets/images/majlisunnoor.png',
      'counter': 'assets/images/counter.png',
    };
    final image = imageByFolderId[id];
    if (image != null) {
      return Image.asset(
        image,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) => Icon(
          Icons.broken_image_outlined,
          size: size,
          color: Theme.of(context).colorScheme.error,
          semanticLabel: 'Unable to load $id icon',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      final only = app.itemsIn(cat.id);
      if (only.length == 1) {
        // one item (Majlisunnoor): open it straight away
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReaderScreen(item: only.first)),
        );
        return;
      }
      if (only.isNotEmpty) {
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

  Widget list(List<Item> items, String emptyText) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => itemTile(context, items[i]),
    );
  }

  void _openById(String id) {
    if (id == 'dikr') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderScreen(
            category: Category(
              id: 'dikr',
              name: 'Dikr',
              ar: 'الأذكار',
              en: 'Dikr',
            ),
          ),
        ),
      );
      return;
    }

    for (final category in app.categories) {
      if (category.id == id) {
        openCategory(category);
        return;
      }
    }
    _msg('This section is not available yet.');
  }

  void _openOther() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.62,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Other sections',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                ),
              ),
              Expanded(
                child: ListView(
                  children: app.categories
                      .map(
                        (category) => ListTile(
                          leading: folderIcon(category.id, 38),
                          title: Text(category.en),
                          subtitle: Text(
                            category.ar,
                            textDirection: TextDirection.rtl,
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            openCategory(category);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AuradSearchScreen()),
    );
  }

  Future<void> _shareApp() async {
    await Clipboard.setData(
      const ClipboardData(text: 'AL AURADU — رياض الأذكار'),
    );
    if (mounted) _msg('App title copied. Public share link is not ready yet.');
  }

  void _switchTab(int selected) {
    Navigator.of(context).pop();
    setState(() => tab = selected);
  }

  Widget _drawer() => Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
                child: Column(
                  children: [
                    Text(
                      kAppName,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: kArabicFont,
                        fontFamilyFallback: kFontFallback,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AL AURADU',
                      style: TextStyle(
                        color: Color(0xFFEBCB84),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home / Library'),
                onTap: () => _switchTab(0),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('My Bookmarks'),
                onTap: () => _switchTab(1),
              ),
              SwitchListTile(
                secondary: Icon(
                  app.dark ? Icons.dark_mode_outlined : Icons.light_mode,
                ),
                title: const Text('Dark mode'),
                value: app.dark,
                onChanged: (_) => app.toggleDark(),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: app.categories
                      .map(
                        (category) => ListTile(
                          leading: SizedBox(
                            width: 38,
                            height: 38,
                            child: folderIcon(category.id, 38),
                          ),
                          title: Text(category.en),
                          subtitle: Text(
                            category.ar,
                            textDirection: TextDirection.rtl,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            openCategory(category);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final colorScheme = auraduColorScheme(app.dark);
        final backgroundColor =
            app.dark ? Colors.black : const Color(0xFF041C3A);
        final theme = Theme.of(context).copyWith(
          brightness: Brightness.dark,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: backgroundColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF041C3A),
            foregroundColor: Color(0xFFFFF4DB),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF041C3A),
            elevation: 0,
            indicatorColor: Color(0xFF25466A),
            height: 72,
          ),
        );
        return Theme(
          data: theme,
          child: Scaffold(
            backgroundColor: backgroundColor,
            drawer: _drawer(),
            appBar: tab == 0
                ? null
                : AppBar(
                    title: const Text('My Bookmarks'),
                    actions: [
                      themeToggleAction(),
                      IconButton(
                        onPressed: () => setState(() => tab = 0),
                        icon: const Icon(Icons.home_outlined),
                        tooltip: 'Go home',
                      ),
                    ],
                  ),
            body: tab == 0
                ? Builder(
                    builder: (scaffoldContext) => ReferenceHome(
                      onMenu: () => Scaffold.of(scaffoldContext).openDrawer(),
                      onShare: _shareApp,
                      onSearch: _openSearch,
                      onOther: _openOther,
                      onFolder: _openById,
                    ),
                  )
                : SafeArea(
                    child: list(
                      app.items
                          .where((item) => app.isBookmarked(item.id))
                          .toList(),
                      'No bookmarks yet',
                    ),
                  ),
            bottomNavigationBar: tab == 0
                ? null
                : NavigationBar(
                    selectedIndex: 1,
                    onDestinationSelected: (index) =>
                        setState(() => tab = index),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.folder_outlined),
                        selectedIcon: Icon(Icons.folder),
                        label: 'Library',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bookmark_border),
                        selectedIcon: Icon(Icons.bookmark),
                        label: 'Bookmarks',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _AuradSearchScreen extends StatefulWidget {
  const _AuradSearchScreen();

  @override
  State<_AuradSearchScreen> createState() => _AuradSearchScreenState();
}

class _AuradSearchScreenState extends State<_AuradSearchScreen> {
  String term = '';
  bool _quranSearchLoadStarted = false;

  void _onQueryChanged(String value) {
    setState(() => term = value);
    if (value.trim().isEmpty || _quranSearchLoadStarted) return;
    _quranSearchLoadStarted = true;
    app.ensureQuranLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = normalize(term.trim());
    final results = q.isEmpty
        ? <Item>[]
        : app.items.where((item) {
            return normalize(item.title).contains(q) ||
                normalize(item.ar).contains(q) ||
                normalize(item.en).contains(q) ||
                item.searchNorm(normalize).contains(q);
          }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [themeToggleAction()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search the library',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? const Center(child: Text('Type to search the library'))
                : results.isEmpty
                    ? const Center(child: Text('Nothing found'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (ctx, index) =>
                            itemTile(ctx, results[index]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FolderIconPainter extends CustomPainter {
  final String id;
  final Color color;

  const _FolderIconPainter(this.id, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void line(double x1, double y1, double x2, double y2) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    void draw(Path path) => canvas.drawPath(path, paint);

    switch (id) {
      case 'quran':
        draw(Path()
          ..moveTo(7, 21)
          ..quadraticBezierTo(19, 17, 31, 23)
          ..lineTo(31, 43)
          ..quadraticBezierTo(18, 37, 7, 41)
          ..close());
        draw(Path()
          ..moveTo(57, 21)
          ..quadraticBezierTo(45, 17, 33, 23)
          ..lineTo(33, 43)
          ..quadraticBezierTo(46, 37, 57, 41)
          ..close());
        line(32, 23, 32, 43);
        line(12, 26, 24, 27);
        line(12, 32, 24, 33);
        line(40, 27, 52, 26);
        line(40, 33, 52, 32);
        line(13, 44, 25, 55);
        line(51, 44, 39, 55);
        line(25, 55, 39, 55);
        line(20, 48, 44, 48);
        break;
      case 'baith':
        draw(Path()
          ..moveTo(8, 29)
          ..quadraticBezierTo(20, 24, 31, 30)
          ..lineTo(31, 48)
          ..quadraticBezierTo(19, 43, 8, 47)
          ..close());
        draw(Path()
          ..moveTo(56, 29)
          ..quadraticBezierTo(44, 24, 33, 30)
          ..lineTo(33, 48)
          ..quadraticBezierTo(45, 43, 56, 47)
          ..close());
        line(32, 30, 32, 48);
        line(12, 34, 24, 35);
        line(40, 35, 52, 34);
        line(32, 7, 32, 16);
        line(19, 11, 23, 19);
        line(45, 11, 41, 19);
        line(9, 21, 17, 25);
        line(55, 21, 47, 25);
        break;
      case 'mawlid':
        line(10, 54, 54, 54);
        line(15, 54, 15, 30);
        line(49, 54, 49, 30);
        draw(Path()
          ..moveTo(15, 31)
          ..lineTo(15, 17)
          ..lineTo(20, 17)
          ..lineTo(20, 31));
        draw(Path()
          ..moveTo(44, 31)
          ..lineTo(44, 17)
          ..lineTo(49, 17)
          ..lineTo(49, 31));
        line(14, 17, 17.5, 12);
        line(43, 17, 46.5, 12);
        line(16, 12, 19, 12);
        line(45, 12, 48, 12);
        draw(Path()
          ..moveTo(22, 36)
          ..quadraticBezierTo(32, 20, 42, 36));
        line(22, 36, 42, 36);
        line(22, 36, 22, 54);
        line(42, 36, 42, 54);
        draw(Path()
          ..moveTo(29, 54)
          ..lineTo(29, 46)
          ..quadraticBezierTo(32, 41, 35, 46)
          ..lineTo(35, 54));
        canvas.drawCircle(const Offset(32, 22), 2, paint);
        break;
      case 'dua':
        draw(Path()
          ..moveTo(31, 53)
          ..lineTo(25, 47)
          ..lineTo(20, 35)
          ..quadraticBezierTo(19, 31, 22, 30)
          ..quadraticBezierTo(24, 29, 26, 33)
          ..lineTo(29, 38)
          ..lineTo(28, 20)
          ..quadraticBezierTo(28, 16, 31, 16)
          ..quadraticBezierTo(34, 16, 34, 20)
          ..lineTo(35, 36));
        draw(Path()
          ..moveTo(35, 36)
          ..lineTo(36, 23)
          ..quadraticBezierTo(36, 19, 39, 19)
          ..quadraticBezierTo(42, 19, 41, 23)
          ..lineTo(40, 37)
          ..lineTo(42, 28)
          ..quadraticBezierTo(43, 24, 46, 25)
          ..quadraticBezierTo(49, 26, 47, 30)
          ..lineTo(45, 43)
          ..quadraticBezierTo(44, 50, 38, 54)
          ..close());
        line(7, 22, 13, 26);
        line(57, 22, 51, 26);
        line(12, 13, 17, 19);
        line(52, 13, 47, 19);
        break;
      case 'ratib':
        canvas.save();
        canvas.translate(32, 32);
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.rotate(i * 3.141592653589793 / 4);
          draw(Path()
            ..moveTo(0, -7)
            ..quadraticBezierTo(5, -15, 0, -25)
            ..quadraticBezierTo(-5, -15, 0, -7)
            ..close());
          canvas.restore();
        }
        canvas.restore();
        canvas.drawCircle(const Offset(32, 32), 7, paint);
        canvas.drawCircle(const Offset(32, 32), 2.5, paint);
        break;
      case 'majlisunnoor':
        draw(Path()
          ..moveTo(9, 55)
          ..lineTo(9, 26)
          ..quadraticBezierTo(9, 18, 17, 18)
          ..quadraticBezierTo(17, 8, 32, 7)
          ..quadraticBezierTo(47, 8, 47, 18)
          ..quadraticBezierTo(55, 18, 55, 26)
          ..lineTo(55, 55));
        draw(Path()
          ..moveTo(18, 55)
          ..lineTo(18, 28)
          ..quadraticBezierTo(18, 24, 23, 24)
          ..quadraticBezierTo(23, 16, 32, 15)
          ..quadraticBezierTo(41, 16, 41, 24)
          ..quadraticBezierTo(46, 24, 46, 28)
          ..lineTo(46, 55));
        line(6, 55, 58, 55);
        line(27, 24, 27, 29);
        line(37, 24, 37, 29);
        line(32, 48, 32, 55);
        break;
      case 'counter':
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, 7, 38, 49),
          const Radius.circular(8),
        );
        canvas.drawRRect(body, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(19, 15, 26, 15),
            const Radius.circular(2),
          ),
          paint,
        );
        line(23, 23, 41, 23);
        canvas.drawCircle(const Offset(32, 42), 5, paint);
        line(32, 37, 32, 35);
        break;
      default:
        canvas.drawCircle(const Offset(32, 32), 21, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FolderIconPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.color != color;
}
