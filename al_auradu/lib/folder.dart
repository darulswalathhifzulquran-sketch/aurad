import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'reader.dart';
import 'mushaf.dart';

/// Left: English letters. Right: Arabic.
Widget itemTile(BuildContext context, Item it) {
  final isQuran = it.category == 'quran' || it.category == 'juz';
  final dim = !it.hasContent && !(mushafReady && isQuran);
  final Color? color = dim ? Theme.of(context).disabledColor : null;
  return ListTile(
    title: Row(
      children: [
        Expanded(
          child: Text(it.title, style: TextStyle(fontSize: 17, color: color)),
        ),
        if (it.ar.isNotEmpty)
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              it.ar,
              style: TextStyle(
                fontFamily: kArabicFont,
                fontFamilyFallback: kFontFallback,
                fontSize: 24,
                color: color,
              ),
            ),
          ),
      ],
    ),
    trailing: app.isBookmarked(it.id)
        ? const Icon(Icons.bookmark, size: 20)
        : (dim ? const Icon(Icons.hourglass_empty, size: 18) : null),
    onTap: () {
      if (mushafReady && isQuran) {
        final n = int.tryParse(it.id.split('-').last) ?? 1;
        final page = it.category == 'quran'
            ? kSurahPage[(n - 1).clamp(0, 113).toInt()]
            : kJuzPage[(n - 1).clamp(0, 29).toInt()];
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MushafScreen(startPage: page)),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderScreen(item: it)),
      );
    },
  );
}

Widget _itemList(List<Item> items) {
  if (items.isEmpty) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nothing added yet', textAlign: TextAlign.center),
      ),
    );
  }
  return ListView.separated(
    itemCount: items.length,
    separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (context, i) => itemTile(context, items[i]),
  );
}

/// Shown while the Mushaf page pictures have not been added.
Widget _withBanner(Widget list) {
  // Intentional empty-library mode must display the normal empty state,
  // not an incorrect warning about missing Quran page files.
  if (mushafReady || kStartWithEmptyLibrary) return list;
  return Column(
    children: [
      Container(
        width: double.infinity,
        color: const Color(0xFFFFF3CD),
        padding: const EdgeInsets.all(10),
        child: const Text(
          'Mushaf page pictures not found (assets/quran/info.json). '
          'Run convert_quran.bat, then stop the app (q) and run it again.',
          style: TextStyle(color: Colors.black87, fontSize: 13),
        ),
      ),
      Expanded(child: list),
    ],
  );
}

Widget _titleRow(Category category) {
  return Row(
    children: [
      Expanded(child: Text(category.en)),
      Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          category.ar,
          style: const TextStyle(
              fontFamily: kArabicFont,
              fontFamilyFallback: kFontFallback,
              fontSize: 26),
        ),
      ),
    ],
  );
}

class FolderScreen extends StatelessWidget {
  final Category category;
  const FolderScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (category.id == 'quran') {
          // Two views: by Surah and by Juz.
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: _titleRow(category),
                bottom: const TabBar(
                  tabs: [Tab(text: 'Surah'), Tab(text: 'Juz')],
                ),
              ),
              body: TabBarView(
                children: [
                  _withBanner(_itemList(app.itemsIn('quran'))),
                  _withBanner(_itemList(app.itemsIn('juz'))),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: _titleRow(category)),
          body: _itemList(app.itemsIn(category.id)),
        );
      },
    );
  }
}
