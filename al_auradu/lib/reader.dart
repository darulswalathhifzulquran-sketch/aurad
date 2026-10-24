import 'dart:async';

import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';

const String kFooterText = 'مجلس صلاة السعادة';
const double kA4 = 1.4142; // A4 height / width

TextStyle bodyStyle(double fs, Color color) => TextStyle(
      fontSize: fs,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: color,
      fontFamily: kArabicFont,
      fontFamilyFallback: kFontFallback,
    );

/// Arabic text runs right-to-left; Malayalam / English paragraphs run
/// left-to-right (decided by which script has more letters).
bool isRtlText(String t) {
  var ar = 0;
  var other = 0;
  for (final r in t.runes) {
    if ((r >= 0x0600 && r <= 0x06FF) ||
        (r >= 0x0750 && r <= 0x077F) ||
        (r >= 0xFB50 && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF)) {
      ar++;
    } else if ((r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A) ||
        (r >= 0x0D00 && r <= 0x0D7F)) {
      other++;
    }
  }
  return ar >= other;
}

double _textH(String t, double fs, double w, TextAlign align) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: bodyStyle(fs, Colors.black)),
    textDirection: isRtlText(t) ? TextDirection.rtl : TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: w);
  return tp.height;
}

// Book style table: thick line on top, under the header, at the bottom and
// down the middle. No lines on the left/right edge and between the rows.
double tableLine(double fs) {
  final l = fs * 0.2;
  return l < 2.5 ? 2.5 : l;
}

// ---------------------------------------------------------------- tables

double _cellWidth(String t, double fs) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: bodyStyle(fs, Colors.black)),
    textDirection: isRtlText(t) ? TextDirection.rtl : TextDirection.ltr,
  )..layout();
  return tp.width;
}

/// Font scale (<= 1) that makes every cell of the table fit on ONE line.
double tableScale(Block b, double fs, double w) {
  if (b.ts > 0) return b.ts;
  final hpad = fs * 0.18;
  final line = tableLine(fs);
  final avail = w / 2 - hpad * 2 - line / 2;
  var mx = 0.0;
  for (final r in [b.head, ...b.rows]) {
    for (final c in r) {
      final cw = _cellWidth(c, fs);
      if (cw > mx) mx = cw;
    }
  }
  if (mx <= 0) return 1;
  final sc = avail * 0.97 / mx;
  if (sc >= 1) return 1;
  return sc < 0.55 ? 0.55 : sc;
}

double _rowHeight(List<String> r, double cfs, double cw, double vpad) {
  double rh = 0;
  for (final c in r) {
    final ch = _textH(c, cfs, cw, TextAlign.center);
    if (ch > rh) rh = ch;
  }
  return rh + vpad * 2;
}

/// Height of one block at font size [fs] and content width [w].
double blockHeight(Block b, double fs, double w) {
  if (b.type == 'image') return w * b.wf / b.aspect;
  if (b.type == 'center') {
    return _textH(b.text, fs * 1.25, w, TextAlign.center);
  }
  if (b.type == 'table') {
    final hpad = fs * 0.18;
    final vpad = fs * 0.04;
    final line = tableLine(fs);
    final cfs = fs * tableScale(b, fs, w);
    final cw = w / 2 - hpad * 2 - line / 2;
    double h = line * (b.head.isNotEmpty ? 3 : 2);
    if (b.head.isNotEmpty) h += _rowHeight(b.head, cfs, cw, vpad);
    for (final r in b.rows) {
      h += _rowHeight(r, cfs, cw, vpad);
    }
    return h;
  }
  return _textH(b.text, fs, w, TextAlign.justify);
}

/// Total height of all blocks at font size [fs] and content width [w].
double contentHeight(List<Block> blocks, double fs, double w) {
  double h = 0;
  for (var i = 0; i < blocks.length; i++) {
    if (i > 0) h += fs * 0.4;
    h += blockHeight(blocks[i], fs, w);
  }
  return h;
}

/// Biggest font size at which the blocks fit inside w x h.
double fitFont(List<Block> blocks, double w, double h) {
  double lo = 6;
  double hi = w * 0.09;
  for (var i = 0; i < 14; i++) {
    final mid = (lo + hi) / 2;
    if (contentHeight(blocks, mid, w) <= h) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

// ---------------------------------------------------------------- reflow
// All pages of an item are poured into one continuous flow, so no page has an
// empty gap at the bottom: whatever follows is moved up as far as it fits.

List<Block>? _splitText(Block b, double fs, double w, double room) {
  final rtl = isRtlText(b.text);
  final tp = TextPainter(
    text: TextSpan(text: b.text, style: bodyStyle(fs, Colors.black)),
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    textAlign: TextAlign.justify,
  )..layout(maxWidth: w);
  final lines = tp.computeLineMetrics();
  if (lines.length < 2) return null;
  var k = 0;
  double acc = 0;
  for (final lm in lines) {
    if (acc + lm.height <= room + 0.5) {
      acc += lm.height;
      k++;
    } else {
      break;
    }
  }
  if (k <= 0 || k >= lines.length) return null;
  final pos = tp.getPositionForOffset(
      Offset(rtl ? w - 1 : 1, acc + lines[k].height / 2));
  final cut = tp.getLineBoundary(pos).start;
  if (cut <= 0 || cut >= b.text.length) return null;
  final head = b.text.substring(0, cut).trimRight();
  final tail = b.text.substring(cut).trimLeft();
  if (head.isEmpty || tail.isEmpty) return null;
  return [Block(type: 'text', text: head), Block(type: 'text', text: tail)];
}

List<Block>? _splitTable(Block b, double fs, double w, double room) {
  final ts = tableScale(b, fs, w);
  final cfs = fs * ts;
  final hpad = fs * 0.18;
  final vpad = fs * 0.04;
  final line = tableLine(fs);
  final cw = w / 2 - hpad * 2 - line / 2;
  double acc = line * (b.head.isNotEmpty ? 3 : 2);
  if (b.head.isNotEmpty) acc += _rowHeight(b.head, cfs, cw, vpad);
  var k = 0;
  for (final r in b.rows) {
    final rh = _rowHeight(r, cfs, cw, vpad);
    if (acc + rh <= room + 0.5) {
      acc += rh;
      k++;
    } else {
      break;
    }
  }
  if (k <= 0 || k >= b.rows.length) return null;
  return [
    Block(type: 'table', head: b.head, rows: b.rows.sublist(0, k), ts: ts),
    Block(type: 'table', head: const [], rows: b.rows.sublist(k), ts: ts),
  ];
}

List<PageData> reflowPages(
    List<PageData> pages, double fs, double w, double h) {
  final queue = <Block>[for (final p in pages) ...p.blocks];
  final out = <PageData>[];
  var cur = <Block>[];
  var used = 0.0;
  final gap = fs * 0.4;

  void flush() {
    if (cur.isNotEmpty) out.add(PageData(cur));
    cur = <Block>[];
    used = 0;
  }

  var i = 0;
  var guard = 0;
  while (i < queue.length && guard++ < 100000) {
    final b = queue[i];
    final g = cur.isEmpty ? 0.0 : gap;
    final bh = blockHeight(b, fs, w);
    final room = h - used - g;
    if (bh <= room + 0.5) {
      cur.add(b);
      used += g + bh;
      i++;
      continue;
    }
    List<Block>? parts;
    if (b.type == 'text') {
      parts = _splitText(b, fs, w, room);
    } else if (b.type == 'table') {
      parts = _splitTable(b, fs, w, room);
    }
    if (parts != null) {
      cur.add(parts[0]);
      queue[i] = parts[1];
      flush();
      continue;
    }
    if (cur.isEmpty) {
      // taller than a whole page: keep it, the page shrinks it to fit
      cur.add(b);
      i++;
      flush();
      continue;
    }
    flush();
  }
  flush();
  return out;
}

class _Reflow {
  final List<PageData> pages;
  final double fs;
  _Reflow(this.pages, this.fs);
}

final Map<String, _Reflow> _reflowCache = {};

_Reflow reflowItem(String key, List<PageData> pages) {
  return _reflowCache.putIfAbsent(key, () {
    const ref = 400.0;
    final w = ref * kTextW;
    final h = ref * kTextH * kA4;
    final fits = pages.map((p) => fitFont(p.blocks, w, h)).toList()..sort();
    final fs = fits[(fits.length - 1) ~/ 2];
    return _Reflow(reflowPages(pages, fs, w, h), fs);
  });
}

// ---------------------------------------------------------------- drawing

Widget buildContent(
    List<Block> blocks, double fs, Color color, bool dark, double w) {
  final children = <Widget>[];
  for (var i = 0; i < blocks.length; i++) {
    if (i > 0) children.add(SizedBox(height: fs * 0.4));
    final b = blocks[i];
    if (b.type == 'image') {
      final white = dark && b.tint;
      children.add(
        Center(
          child: FractionallySizedBox(
            widthFactor: b.wf,
            child: Image.asset(
              b.asset,
              fit: BoxFit.fitWidth,
              color: white ? Colors.white : null,
              colorBlendMode: white ? BlendMode.srcIn : null,
              errorBuilder: (_, __, ___) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Picture not found:\n${b.asset}\nCopy the whole assets/pages '
                  'folder, check pubspec.yaml has - assets/pages/ and restart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: fs * 0.8),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (b.type == 'center') {
      children.add(
        Text(
          b.text,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: bodyStyle(fs * 1.25, color),
        ),
      );
    } else if (b.type == 'table') {
      final hpad = fs * 0.18;
      final vpad = fs * 0.04;
      final line = tableLine(fs);
      final cfs = fs * tableScale(b, fs, w);
      final hasHead = b.head.isNotEmpty;
      final rows = [if (hasHead) b.head, ...b.rows];
      children.add(
        Table(
          border: TableBorder(
            top: BorderSide(color: color, width: line),
            bottom: BorderSide(color: color, width: line),
            verticalInside: BorderSide(color: color, width: line * 0.85),
          ),
          children: [
            for (var r = 0; r < rows.length; r++)
              TableRow(
                decoration: (hasHead && r == 0)
                    ? BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: color, width: line)),
                      )
                    : null,
                children: [
                  for (final c in rows[r])
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: hpad, vertical: vpad),
                      child: Text(
                        c,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: bodyStyle(cfs, color),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    } else {
      children.add(
        Directionality(
          textDirection:
              isRtlText(b.text) ? TextDirection.rtl : TextDirection.ltr,
          child: Text(
            b.text,
            textAlign: TextAlign.justify,
            textScaler: TextScaler.noScaling,
            style: bodyStyle(fs, color),
          ),
        ),
      );
    }
  }
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

// Text area inside the border, as fractions of the page.
const double kTextL = 0.071;
const double kTextW = 0.858;
const double kTextT = 0.058;
const double kTextH = 0.877;

final Map<String, List<double>> _itemFontCache = {};

/// Font size for every page of an item (reference width 400).
/// Each page is filled as much as possible; only very short pages are
/// capped, so they do not show giant letters.
List<double> itemFonts(String key, List<PageData> pages) {
  return _itemFontCache.putIfAbsent(key, () {
    const ref = 400.0;
    final fits = pages
        .map((p) => fitFont(p.blocks, ref * kTextW, ref * kTextH * kA4))
        .toList();
    if (fits.length < 2) return fits;
    final sorted = [...fits]..sort();
    final cap = sorted[(sorted.length - 1) ~/ 2] * 1.25;
    return fits.map((f) => f > cap ? cap : f).toList();
  });
}

class PageSheet extends StatelessWidget {
  final PageData page;
  final double width;
  final bool dark;
  final double baseFont; // font size at reference width 400
  const PageSheet(
      {super.key,
      required this.page,
      required this.width,
      required this.dark,
      required this.baseFont});

  double _fontSize() => baseFont * (width / 400.0);

  @override
  Widget build(BuildContext context) {
    final height = width * kA4;
    final innerW = width * kTextW;
    final innerH = height * kTextH;
    final fs = _fontSize();
    final textColor = dark ? Colors.white : Colors.black;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
  color: dark ? Colors.black : Colors.white,
  boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black38)],
),
      ),
      child: Stack(
        children: [
          // Dark mode: the inside of the frame turns black.
          if (dark)
            Positioned(
              left: width * 0.052,
              top: height * 0.036,
              width: width * 0.894,
              height: height * 0.911,
              child: const ColoredBox(color: Colors.black),
            ),
          Positioned.fill(
            child: Image.asset('assets/images/border.png', fit: BoxFit.fill),
          ),
          Positioned(
            left: width * kTextL,
            top: height * kTextT,
            width: innerW,
            height: innerH,
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: innerW,
                  child: buildContent(
                      page.blocks, fs, textColor, dark, innerW),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final Item item;
  const ReaderScreen({super.key, required this.item});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final PageController ctrl = PageController();
  final ScrollController sc = ScrollController();
  int index = 0;

  // Quran (surah / juz): pages turn sideways. Everything else: scrolling.
  bool get paged =>
      widget.item.category == 'quran' || widget.item.category == 'juz';

  @override
  void dispose() {
    ctrl.dispose();
    sc.dispose();
    super.dispose();
  }

  void _go(int to, int total) {
    if (to < 0 || to >= total) return;
    ctrl.animateToPage(to,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _pagedBody(List<PageData> pages, List<double> bases) {
    return LayoutBuilder(
      builder: (context, c) {
        final fitW = (c.maxWidth - 20) < (c.maxHeight - 20) / kA4
            ? (c.maxWidth - 20)
            : (c.maxHeight - 20) / kA4;
        final pageW = fitW * app.zoom;
        final zoomed = app.zoom > 1.01;
        // Arabic book: pages turn right-to-left (reverse: true).
        return PageView.builder(
          controller: ctrl,
          reverse: true,
          physics: zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: pages.length,
          onPageChanged: (i) => setState(() => index = i),
          itemBuilder: (context, i) => SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: c.maxWidth, minHeight: c.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child:
                        PageSheet(
                        page: pages[i],
                        width: pageW,
                        dark: app.dark,
                        baseFont: bases[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scrollBody(List<PageData> pages, List<double> bases) {
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final fitW = (c.maxWidth - 20) < (c.maxHeight - 20) / kA4
                  ? (c.maxWidth - 20)
                  : (c.maxHeight - 20) / kA4;
              final pageW = fitW * app.zoom;
              return SingleChildScrollView(
                controller: sc,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (var i = 0; i < pages.length; i++) ...[
                            PageSheet(
                                page: pages[i],
                                width: pageW,
                                dark: app.dark,
                                baseFont: bases[i]),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Side speed slider: move it up/down and it stays there; the further from the middle, the faster it scrolls.
        SizedBox(width: 48, child: SpeedSlider(controller: sc)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final pages = item.hasContent
            ? item.pages
            : [
                PageData([
                  Block(
                    type: 'text',
                    text: (item.category == 'quran' || item.category == 'juz') &&
                            quranStatus.isNotEmpty
                        ? quranStatus
                        : 'Content not added yet',
                  )
                ])
              ];
        final key =
            '${item.id}-${pages.fold<int>(0, (a, p) => a ^ p.plain.hashCode)}';
        List<PageData> shown = pages;
        List<double> bases;
        final hasText =
            pages.any((p) => p.blocks.any((b) => b.type != 'image'));
        if (!paged && pages.length > 1 && hasText) {
          final r = reflowItem(key, pages);
          shown = r.pages;
          bases = List<double>.filled(shown.length, r.fs);
        } else {
          bases = itemFonts(key, pages);
        }
        final total = shown.length;
        return Scaffold(
          backgroundColor:
              app.dark ? const Color(0xFF121212) : const Color(0xFFE9E9E9),
          appBar: AppBar(
            title: Text(item.ar.isEmpty ? item.title : item.ar,
                style: const TextStyle(
                    fontFamily: kArabicFont,
                    fontFamilyFallback: kFontFallback,
                    fontSize: 26)),
            actions: [
              IconButton(
                tooltip: 'Dark mode',
                icon: Icon(app.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: app.toggleDark,
              ),
              IconButton(
                tooltip: 'Bookmark',
                icon: Icon(app.isBookmarked(item.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border),
                onPressed: () => app.toggleBookmark(item.id),
              ),
            ],
          ),
          body: paged ? _pagedBody(shown, bases) : _scrollBody(shown, bases),
          bottomNavigationBar: BottomAppBar(
            child: Row(
              children: [
                if (paged) ...[
                  // Pages turn right-to-left, so "next" is the left arrow.
                  IconButton(
                    tooltip: 'Next page',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: index < total - 1
                        ? () => _go(index + 1, total)
                        : null,
                  ),
                  Text('${index + 1} / $total'),
                  IconButton(
                    tooltip: 'Previous page',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: index > 0 ? () => _go(index - 1, total) : null,
                  ),
                ],
                const SizedBox(width: 8),
                const Icon(Icons.zoom_in, size: 22),
                Expanded(
                  child: Slider(
                    min: 1.0,
                    max: 2.5,
                    value: app.zoom,
                    onChanged: app.setZoom,
                  ),
                ),
                Text('${(app.zoom * 100).round()}%'),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Side slider for scrolling. Middle = stopped. Move it up or down and it
/// STAYS where you leave it; the further from the middle, the faster the page
/// scrolls. Move it back to the middle (or reach the end) to stop.
class SpeedSlider extends StatefulWidget {
  final ScrollController controller;
  const SpeedSlider({super.key, required this.controller});

  @override
  State<SpeedSlider> createState() => _SpeedSliderState();
}

class _SpeedSliderState extends State<SpeedSlider> {
  // Scroll speed (pixels per second) at the very end of the slider.
  // Make this bigger for faster scrolling.
  static const double gain = 85; // very slow: about one Arabic line every few seconds

  double push = 0; // 0 = at top/stopped, 1 = slow down
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _tick(Timer _) {
    if (push == 0) return;
    final c = widget.controller;
    if (!c.hasClients) return;
    final max = c.position.maxScrollExtent;
    final next = (c.offset + push * gain * 0.016).clamp(0.0, max);
    c.jumpTo(next);
    if (next >= max) {
      setState(() => push = 0);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 6),
        const Icon(Icons.keyboard_arrow_up, size: 22),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // little mark at the middle (= stop)
              Container(width: 18, height: 2, color: scheme.outline),
              RotatedBox(
                quarterTurns: 1,
                child: Slider(
                  min: 0,
                  max: 1,
                  value: push,
                  onChanged: (v) =>
                      setState(() => push = v < 0.02 ? 0 : v),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.keyboard_arrow_down, size: 22),
        const SizedBox(height: 6),
      ],
    );
  }
}
