import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models.dart';
import 'store.dart';
import 'reader.dart';
import 'mushaf.dart';
import 'quran_line_reader.dart';

const List<String> kJuzOpeningNames = [
  'الم', 'سيقول', 'تلك الرسل', 'لن تنالوا', 'والمحصنات',
  'لا يحب الله', 'وإذا سمعوا', 'ولو أننا', 'قال الملأ', 'واعلموا',
  'يعتذرون', 'وما من دابة', 'وما أبرئ', 'ربما', 'سبحان الذي',
  'قال ألم', 'اقترب', 'قد أفلح', 'وقال الذين', 'أمن خلق',
  'اتل ما أوحي', 'ومن يقنت', 'وما لي', 'فمن أظلم', 'إليه يرد',
  'حم', 'قال فما خطبكم', 'قد سمع', 'تبارك الذي', 'عم',
];

String _arabicDigits(int number) => number.toString().replaceAllMapped(
  RegExp(r'[0-9]'),
  (match) => String.fromCharCode(0x0660 + int.parse(match.group(0)!)),
);

/// Left: English letters. Right: Arabic.
Widget itemTile(BuildContext context, Item it) {
  final isJuz = it.category == 'juz';
  final isQuran = it.category == 'quran' || isJuz;
  final number = int.tryParse(it.id.split('-').last);
  final isNumberedQuran = isQuran && number != null;
  final englishTitle = isJuz && number != null
      ? it.title.replaceFirst(RegExp(r'^Juz\s+\d+\s*-\s*', caseSensitive: false), '')
      : isNumberedQuran
          ? it.title.replaceFirst(RegExp(r'^\d+\.\s*'), '')
          : it.title;
  final isNumbered = isQuran && number != null;
  final arabic = isJuz && number != null && number >= 1 && number <= 30
      ? _arabicDigits(number) + ' - ' + kJuzOpeningNames[number - 1]
      : isNumbered
          ? it.ar.replaceFirst(RegExp(r'^سورة\s*'), '')
          : it.ar;
  final english = isJuz && number != null
      ? number.toString() + ' - ' + englishTitle
      : englishTitle;
  final quranPage = isNumbered && number != null && number >= 1
      ? (isJuz && number <= 30
          ? kJuzPage[number - 1]
          : (!isJuz && number <= 114 ? kSurahPage[number - 1] : null))
      : null;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: Material(
      color: const Color(0xFF092440),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () {
          if (mushafReady && isQuran) {
            final n = number ?? 1;
            final page = it.category == 'quran'
                ? kSurahPage[(n - 1).clamp(0, 113).toInt()]
                : kJuzPage[(n - 1).clamp(0, 29).toInt()];
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => QuranLineReader(startPage: page)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReaderScreen(item: it)),
            );
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFF0868AF), width: 1.15),
          ),
          child: Row(
            children: [
              if (isNumbered) ...[
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF061B30),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFEBCB84), width: 1.6),
                  ),
                  child: Text(number.toString(),
                    style: const TextStyle(
                      color: Color(0xFFFFE4A2),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(english,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFF4DF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (quranPage != null)
                      Text('Page ' + quranPage.toString(),
                        style: const TextStyle(
                          color: Color(0xFFB9C8D9),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (arabic.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      arabic,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: kArabicFont,
                        fontFamilyFallback: kFontFallback,
                        color: Color(0xFFFFF4DF),
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Color(0xFFFFE4A2)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _itemList(List<Item> items) {
  if (items.isEmpty) {
    return const Center(child: Text('Nothing added yet'));
  }
  return ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 10),
    itemCount: items.length,
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
  final arabic = category.id == 'quran' ? 'القرآن الكريم' : category.ar;
  final english = category.id == 'quran' ? "Holy Qur'an" : category.en;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        arabic,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontFamily: kArabicFont,
          fontSize: 22,
          color: Color(0xFFFFF4DB),
          height: 1.05,
        ),
      ),
      Text(
        english,
        style: const TextStyle(fontSize: 12, color: Color(0xFFFFF4DB), height: 1.05),
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
          body: ColoredBox(
            color: app.dark ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
            child: _itemList(app.itemsIn(category.id)),
          ),
        );
      },
    );
  }
}
