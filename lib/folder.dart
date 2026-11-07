import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models.dart';
import 'store.dart';
import 'reader.dart';
import 'mushaf.dart';

/// Left: English letters. Right: Arabic.
Widget itemTile(BuildContext context, Item it) {
  final isQuran = it.category == 'quran' || it.category == 'juz';
  final dim =
      !it.hasContent && it.pdfAsset.isEmpty && !(mushafReady && isQuran);
  final Color? color = dim ? Theme.of(context).disabledColor : null;
  final number = int.tryParse(it.id.split('-').last);
  final isNumberedQuran = isQuran && number != null;
  final englishTitle = isNumberedQuran
      ? it.title.replaceFirst(RegExp(r'^\d+\.\s*'), '')
      : it.title;
  final arabicNumber = isNumberedQuran
      ? number.toString().replaceAllMapped(
          RegExp(r'[0-9]'),
          (m) => String.fromCharCode(0x0660 + int.parse(m.group(0)!)),
        )
      : '';
  return ListTile(
    title: Row(
      children: [
        Expanded(
          child: Text(
            isNumberedQuran ? '$number. $englishTitle' : it.title,
            style: TextStyle(
              fontSize: 17,
              color: color,
              fontFamily: 'Arial',
              letterSpacing: 0,
              wordSpacing: 0,
            ),
          ),
        ),
        if (it.ar.isNotEmpty)
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              isNumberedQuran ? '$arabicNumber - ${it.ar}' : it.ar,
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

/// Shown while the Mushaf source metadata has not been added.
Widget _withBanner(Widget list) {
  if (mushafReady) return list;
  return Column(
    children: [
      Container(
        width: double.infinity,
        color: const Color(0xFFFFF3CD),
        padding: const EdgeInsets.all(10),
        child: const Text(
          'Quran source metadata is missing '
          '(assets/quran - Copy/info.json). Check that quran.pdf is bundled.',
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
                actions: [themeToggleAction()],
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
          appBar: AppBar(
            title: _titleRow(category),
            actions: [themeToggleAction()],
          ),
          body: _itemList(app.itemsIn(category.id)),
        );
      },
    );
  }
}
