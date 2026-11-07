import 'package:flutter/material.dart';
import 'store.dart';

/// First page (Madinah Mushaf, 604 pages) of every surah.
const List<int> kSurahPage = [
  1, 2, 50, 77, 106, 128, 151, 177, 187, 208, 221, 235, 249, 255, 262, 267,
  282, 293, 305, 312, 322, 332, 342, 350, 359, 367, 377, 385, 396, 404, 411,
  415, 418, 428, 434, 440, 446, 453, 458, 467, 477, 483, 489, 496, 499, 502,
  507, 511, 515, 518, 520, 523, 526, 528, 531, 534, 537, 542, 545, 549, 551,
  553, 554, 556, 558, 560, 562, 564, 566, 568, 570, 572, 574, 575, 577, 578,
  580, 582, 583, 585, 586, 587, 587, 589, 590, 591, 591, 592, 593, 594, 595,
  595, 596, 596, 597, 597, 598, 598, 599, 599, 600, 600, 601, 601, 601, 602,
  602, 602, 603, 603, 603, 604, 604, 604,
];

/// First page of every juz.
const List<int> kJuzPage = [
  1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, 302,
  322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
];

String mushafPath(int page) =>
    'assets/quran/${page.toString().padLeft(3, '0')}.$mushafExt';

int surahAtPage(int page) {
  var s = 1;
  for (var i = 0; i < 114; i++) {
    if (kSurahPage[i] <= page) s = i + 1;
  }
  return s;
}

int juzAtPage(int page) {
  var j = 1;
  for (var i = 0; i < 30; i++) {
    if (kJuzPage[i] <= page) j = i + 1;
  }
  return j;
}

const List<double> _invert = <double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255,
  0, 0, -1, 0, 255,
  0, 0, 0, 1, 0,
];

class MushafScreen extends StatefulWidget {
  final int startPage;
  const MushafScreen({super.key, this.startPage = 1});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late final PageController ctrl;
  late int page;
  final ValueNotifier<bool> zoomed = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    page = widget.startPage.clamp(1, mushafCount).toInt();
    ctrl = PageController(initialPage: page - 1);
  }

  @override
  void dispose() {
    ctrl.dispose();
    zoomed.dispose();
    super.dispose();
  }

  void _goto(int p) {
    final t = p.clamp(1, mushafCount).toInt();
    ctrl.jumpToPage(t - 1);
  }

  void _precache(int index) {
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < mushafCount) {
        precacheImage(AssetImage(mushafPath(i + 1)), context)
            .catchError((_) {});
      }
    }
  }

  Future<void> _askPage() async {
    final tc = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: tc,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - $mushafCount'),
          onSubmitted: (s) => Navigator.pop(c, int.tryParse(s)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, int.tryParse(tc.text)),
              child: const Text('Go')),
        ],
      ),
    );
    if (v != null) _goto(v);
  }

  String _surahName(int n) {
    for (final it in app.items) {
      if (it.category == 'quran' && it.id == 'quran-$n') return it.title;
    }
    return 'Surah $n';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final dark = app.dark;
        return Scaffold(
          backgroundColor: dark ? Colors.black : const Color(0xFFF2F2F2),
          appBar: AppBar(
            title: Text(
                '${_surahName(surahAtPage(page))}  \u2022  Juz ${juzAtPage(page)}'),
            actions: [
              IconButton(
                tooltip: 'Go to page',
                icon: const Icon(Icons.find_in_page_outlined),
                onPressed: _askPage,
              ),
              IconButton(
                tooltip: 'Dark / light',
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: app.toggleDark,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: zoomed,
                  builder: (context, z, _) => PageView.builder(
                    controller: ctrl,
                    reverse: true, // Arabic book: next page is on the left
                    physics: z
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: mushafCount,
                    onPageChanged: (i) {
                      setState(() => page = i + 1);
                      zoomed.value = false;
                      app.prefs.setInt('mushaf_page', i + 1);
                      _precache(i);
                    },
                    itemBuilder: (context, i) => _MushafPage(
                      key: ValueKey(i),
                      page: i + 1,
                      dark: dark,
                      onZoom: (v) => zoomed.value = v,
                    ),
                  ),
                ),
              ),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: mushafCount.toDouble(),
                        value: page.toDouble().clamp(1, mushafCount.toDouble()),
                        onChanged: (v) => setState(() => page = v.round()),
                        onChangeEnd: (v) => _goto(v.round()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$page / $mushafCount'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MushafPage extends StatefulWidget {
  final int page;
  final bool dark;
  final ValueChanged<bool> onZoom;
  const _MushafPage(
      {super.key,
      required this.page,
      required this.dark,
      required this.onZoom});

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  final TransformationController tc = TransformationController();
  Offset tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    tc.addListener(() => widget.onZoom(tc.value.getMaxScaleOnAxis() > 1.02));
  }

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  void _doubleTap() {
    if (tc.value.getMaxScaleOnAxis() > 1.02) {
      tc.value = Matrix4.identity();
    } else {
      const s = 2.5;
      tc.value = Matrix4.identity()
        ..setEntry(0, 0, s)
        ..setEntry(1, 1, s)
        ..setEntry(0, 3, -tapAt.dx * (s - 1))
        ..setEntry(1, 3, -tapAt.dy * (s - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      mushafPath(widget.page),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Center(
        child: Text('Page ${widget.page}: image not found',
            style: TextStyle(color: widget.dark ? Colors.white : Colors.black)),
      ),
    );
    final child = widget.dark
        ? ColorFiltered(colorFilter: const ColorFilter.matrix(_invert), child: img)
        : img;
    return GestureDetector(
      onDoubleTapDown: (d) => tapAt = d.localPosition,
      onDoubleTap: _doubleTap,
      child: InteractiveViewer(
        transformationController: tc,
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}
