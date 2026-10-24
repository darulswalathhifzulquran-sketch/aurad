import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'aurad_settings.dart';
import 'aurad_theme.dart';
import 'counter.dart';
import 'folder.dart';
import 'models.dart';
import 'reader.dart';
import 'reference_home.dart';
import 'store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String query = '';

  @override
  void initState() {
    super.initState();
    if (extrasStatus.isNotEmpty &&
        !extrasStatus.startsWith('Extra content OK')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extrasStatus),
            duration: const Duration(seconds: 12),
            showCloseIcon: true,
          ),
        );
      });
    }
  }

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

  void _msg(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openCategory(Category category) async {
    if (category.type == 'counter') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CounterScreen()),
      );
      return;
    }
    if (category.type == 'pdf') {
      final only = app.itemsIn(category.id);
      if (only.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FolderScreen(category: category)),
        );
        return;
      }
      if (category.pdf.isEmpty) {
        // Keep the folder tappable even when all books have been cleared.
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FolderScreen(category: category)),
        );
        return;
      }
      final ok = await launchUrl(
        Uri.parse(category.pdf),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) _msg('Could not open the PDF');
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => FolderScreen(category: category)),
    );
  }

  List<Item> get searchResults {
    final q = normalize(query.trim());
    return app.items.where((item) {
      return normalize(item.title).contains(q) ||
          normalize(item.ar).contains(q) ||
          normalize(item.en).contains(q) ||
          item.searchNorm(normalize).contains(q);
    }).toList();
  }

  Widget _folderIcon(Category category) {
    // The GitHub snapshot currently lacks the approved colorful PNGs.
    // Preserve its existing icons until the image assets are uploaded.
    return Icon(
      iconFor(category.id),
      size: 36,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  Widget folderGrid() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width < 330 ? 1 : width < 700 ? 2 : 3;
              final cardHeight = width < 700 ? 186.0 : 208.0;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 17,
                  mainAxisExtent: cardHeight,
                ),
                itemCount: app.categories.length,
                itemBuilder: (context, index) {
                  final category = app.categories[index];
                  final count =
                      (category.type == 'pdf' &&
                              app.itemsIn(category.id).isEmpty)
                          ? 'PDF'
                          : (category.type == 'counter'
                              ? app.counter.toString()
                              : app.itemsIn(category.id).length.toString());
                  return AuradPanel(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    onTap: () {
                      openCategory(category);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _folderIcon(category),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              category.ar,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: kArabicFont,
                                fontFamilyFallback: kFontFallback,
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          category.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category.en,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AuradColors.secondaryText(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          count,
                          style: TextStyle(
                            fontSize: 12,
                            color: AuradColors.secondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      );

  Widget _list(List<Item> items, String emptyText) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => itemTile(context, items[index]),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _switchTab(int selected) {
    Navigator.of(context).pop();
    setState(() => tab = selected);
  }

  void _openQuranFromDrawer() {
    Navigator.of(context).pop();
    for (final category in app.categories) {
      if (category.id == 'quran') {
        openCategory(category);
        return;
      }
    }
    _msg('Quran section is not available');
  }

  void _drawerMessage(String message) {
    Navigator.of(context).pop();
    _msg(message);
  }

  Widget _drawer() => Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: AuradPanel(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AuradColors.emerald,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.menu_book_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kAppName,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: kArabicFont,
                                fontFamilyFallback: kFontFallback,
                                fontSize: 23,
                              ),
                            ),
                            Text(
                              'AL AURADU',
                              style: TextStyle(
                                color: AuradColors.secondaryText(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Home / Library'),
                      onTap: () => _switchTab(0),
                    ),
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('Quran'),
                      onTap: _openQuranFromDrawer,
                    ),
                    ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: const Text('My Bookmarks'),
                      onTap: () => _switchTab(1),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('My Account'),
                      subtitle: const Text('Guest'),
                      onTap: () => _openPage(const AuradAccountScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.login_outlined),
                      title: const Text('Login / Sign up'),
                      onTap: () => _openPage(const AuradAccountScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      onTap: () => _openPage(const AuradSettingsScreen()),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Help & Support'),
                      onTap: () => _drawerMessage(
                          'Support contact is not configured yet.'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About App'),
                      onTap: () => _openPage(const AuradSettingsScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy Policy'),
                      onTap: () => _drawerMessage(
                          'A verified privacy policy has not been added yet.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  void _openById(String id) {
    if (id == 'dikr') {
      // Dikr is a visual destination in the approved design and should
      // open an empty library page until devotional content is added.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderScreen(
            category: Category(
              id: 'dikr',
              name: 'ദിക്ർ',
              ar: 'الأذكار',
              en: 'Dikr',
            ),
          ),
        ),
      );
      return;
    }
    final matching = app.categories.where((c) => c.id == id);
    if (matching.isEmpty) {
      _msg('This section is not available yet.');
      return;
    }
    openCategory(matching.first);
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
                  children: app.categories.map((cat) => ListTile(
                    leading: Icon(iconFor(cat.id)),
                    title: Text(cat.en),
                    subtitle: Text(cat.ar,
                        textDirection: TextDirection.rtl),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      openCategory(cat);
                    },
                  )).toList(),
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
    // No public Play Store listing exists yet.
    await Clipboard.setData(
      const ClipboardData(text: 'AL AURADU — رياض الأذكار'),
    );
    if (mounted) _msg('App title copied. Public share link is not ready yet.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        drawer: _drawer(),
        appBar: tab == 0
            ? null
            : AppBar(
                title: const Text('My Bookmarks'),
                actions: [
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
                child: _list(
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
  }
}

class _AuradSearchScreen extends StatefulWidget {
  const _AuradSearchScreen();

  @override
  State<_AuradSearchScreen> createState() => _AuradSearchScreenState();
}

class _AuradSearchScreenState extends State<_AuradSearchScreen> {
  String term = '';

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
      appBar: AppBar(title: const Text('Search')),
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
              onChanged: (text) => setState(() => term = text),
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
