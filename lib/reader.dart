import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdfrx/pdfrx.dart';
import 'app_theme.dart';
import 'dark_document_renderer.dart';
import 'models.dart';
import 'auto_scroll_speed_slider.dart';
import 'store.dart';

const double kA4 = 1.4142; // A4 height / width

const Map<String, double> _footerImageCrop = {
  'assets/pages/haddad_012.webp': 0.80,
  'assets/pages/muhyi_032.webp': 0.87,
  'assets/pages/nafeesa_030.webp': 0.48,
  'assets/pages/rifai_036.webp': 0.88,
};
const Map<String, String> _cleanImageAssets = {
  'assets/pages/haddad_012.webp': 'assets/pages/haddad_012_clean.png',
  'assets/pages/muhyi_032.webp': 'assets/pages/muhyi_032_clean.png',
  'assets/pages/nafeesa_030.webp': 'assets/pages/nafeesa_030_clean.png',
  'assets/pages/rifai_036.webp': 'assets/pages/rifai_036_clean.png',
};
const String _footerOnlyImage = 'assets/pages/rifai_036.webp';

bool _isFooterOnlyPage(PageData page) =>
    page.blocks.isNotEmpty &&
    page.blocks.every((b) => b.type == 'image' && b.asset == _footerOnlyImage);

TextStyle bodyStyle(double fs, Color color) => TextStyle(
      fontSize: fs,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: color,
      fontFamily: kArabicFont,
      fontFamilyFallback: kFontFallback,
    );

TextStyle _titleStyle(double fs, Color color) => TextStyle(
      fontSize: fs,
      height: 1.45,
      fontWeight: FontWeight.w700,
      color: color,
      fontFamily: 'Amiri',
      fontFamilyFallback: [kArabicFont, ...kFontFallback],
    );

double _bookTitleFontSize(double fs, double w) {
  final scaled = fs * 1.65;
  final prominent = w * 0.08;
  return scaled > prominent ? scaled : prominent;
}

double _titleHeight(String text, double fs, double w) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: _titleStyle(fs, Colors.black)),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  )..layout(maxWidth: w);
  return tp.height;
}

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

double _tableCellHpad(double fs) => fs * 0.14;

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
  final hpad = _tableCellHpad(fs);
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
  if (b.type == 'image')
    return w * b.wf / b.aspect * (_footerImageCrop[b.asset] ?? 1.0);
  if (b.type == 'center' || b.type == 'title') {
    if (b.type == 'title') {
      return _titleHeight(b.text, _bookTitleFontSize(fs, w), w);
    }
    return _textH(b.text, fs * 1.25, w, TextAlign.center);
  }
  if (b.type == 'table') {
    final hpad = _tableCellHpad(fs);
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
  final pos = tp
      .getPositionForOffset(Offset(rtl ? w - 1 : 1, acc + lines[k].height / 2));
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
  final hpad = _tableCellHpad(fs);
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

_Reflow reflowItem(String key, List<PageData> pages, {required bool quran}) {
  return _reflowCache.putIfAbsent(key, () {
    const ref = 400.0;
    final w = ref * _textWidth(quran);
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
      if (b.asset == _footerOnlyImage) continue;
      final imageAsset = _cleanImageAssets[b.asset] ?? b.asset;
      final image = Image.asset(
        imageAsset,
        fit: BoxFit.fitWidth,
        color: dark && b.tint ? Colors.white : null,
        colorBlendMode: dark && b.tint ? BlendMode.srcIn : null,
        errorBuilder: (_, __, ___) => Semantics(
          label: 'Page artwork unavailable: $imageAsset',
          child: SizedBox(
            height: fs * 2.4,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      size: fs, color: color.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Text(
                    'Page artwork unavailable',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: fs * 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final displayImage = dark && !b.tint
          ? ColorFiltered(
              colorFilter: darkDocumentColorFilter,
              child: image,
            )
          : image;
      // Majlisunnoor images contain a light outer margin *inside the image*.
      // The PDF overlay does not affect these WebP pages. Cover only their
      // known empty outer strips in dark mode, preserving the gold frame,
      // Arabic letters and the user's existing scrolling/zoom behavior.
      final framedImage = dark && b.asset.startsWith('assets/pages/majlis_')
          ? AspectRatio(
              aspectRatio: b.aspect,
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final w = bounds.maxWidth;
                  final h = bounds.maxHeight;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      displayImage,
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        width: w * 0.022,
                        child: const ColoredBox(color: Colors.black),
                      ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: w * 0.022,
                        child: const ColoredBox(color: Colors.black),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: h * 0.018,
                        child: const ColoredBox(color: Colors.black),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: h * 0.034,
                        child: const ColoredBox(color: Colors.black),
                      ),
                    ],
                  );
                },
              ),
            )
          : displayImage;
      children.add(
        Center(
          child: FractionallySizedBox(
            widthFactor: b.wf,
            child: framedImage,
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
    } else if (b.type == 'title') {
      children.add(
        Text(
          b.text,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: _titleStyle(
            _bookTitleFontSize(fs, w),
            dark ? darkDocumentTitleColor : const Color(0xFFB3261E),
          ),
        ),
      );
    } else if (b.type == 'table') {
      final hpad = _tableCellHpad(fs);
      final vpad = fs * 0.04;
      final line = tableLine(fs);
      final cfs = fs * tableScale(b, fs, w);
      final hasHead = b.head.isNotEmpty;
      final rows = [if (hasHead) b.head, ...b.rows];
      children.add(
        Table(
          defaultColumnWidth: const FlexColumnWidth(),
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

const double _bookTextL = 0.058;
const double _bookTextW = 0.884;

double _textWidth(bool quran) => quran ? kTextW : _bookTextW;
double _textLeft(bool quran) => quran ? kTextL : _bookTextL;

final Map<String, List<double>> _itemFontCache = {};

/// Font size for every page of an item (reference width 400).
/// Each page is filled as much as possible; only very short pages are
/// capped, so they do not show giant letters.
List<double> itemFonts(String key, List<PageData> pages,
    {required bool quran}) {
  return _itemFontCache.putIfAbsent(key, () {
    const ref = 400.0;
    final textW = ref * _textWidth(quran);
    final fits =
        pages.map((p) => fitFont(p.blocks, textW, ref * kTextH * kA4)).toList();
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
  final bool quran;
  final double baseFont; // font size at reference width 400
  const PageSheet(
      {super.key,
      required this.page,
      required this.width,
      required this.dark,
      required this.quran,
      required this.baseFont});

  double _fontSize() => baseFont * (width / 400.0);

  @override
  Widget build(BuildContext context) {
    final height = width * kA4;
    final textL = _textLeft(quran);
    final textW = _textWidth(quran);
    final innerW = width * textW;
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
          if (!quran)
            Positioned.fill(
              child: Image.asset(
                'assets/images/border.png',
                fit: BoxFit.fill,
              ),
            ),
          Positioned(
            left: width * textL,
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
                  child: buildContent(page.blocks, fs, textColor, dark, innerW),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Set<String> _titledBookCategories = {
  'baith',
  'mawlid',
  'swalath',
  'dua',
  'ratib',
  'mala',
  'majlisunnoor',
};

List<PageData> _withBookTitle(Item item, List<PageData> pages) {
  if (!_titledBookCategories.contains(item.category) ||
      item.ar.trim().isEmpty) {
    return pages;
  }

  final title = Block(type: 'title', text: item.ar.trim());
  if (pages.isEmpty)
    return [
      PageData([title])
    ];

  final first = pages.first;
  final titleArtwork = first.blocks.any(
    (b) => b.type == 'image' && b.asset.toLowerCase().contains('title'),
  );
  if (titleArtwork) return pages;

  return [
    PageData([title, ...first.blocks]),
    ...pages.skip(1),
  ];
}

class ReaderScreen extends StatefulWidget {
  final Item item;
  const ReaderScreen({super.key, required this.item});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _autoScrollTicker;
  Duration _lastAutoScrollElapsed = Duration.zero;
  double _autoScrollSpeed = 0;
  final PageController ctrl = PageController();
  final ScrollController sc = ScrollController();
  final PdfViewerController _pdfController = PdfViewerController();
  int index = 0;
  int _pdfPageCount = 0;
  int _scrollPageCount = 0;

  // Quran (surah / juz): pages turn sideways. Everything else: scrolling.
  bool get paged =>
      widget.item.category == 'quran' || widget.item.category == 'juz';

  @override
  void initState() {
    super.initState();
    _autoScrollTicker = createTicker(_autoScrollFrame);
    sc.addListener(_scrollChanged);
  }

  @override
  void dispose() {
    _autoScrollTicker.dispose();
    sc.removeListener(_scrollChanged);
    ctrl.dispose();
    sc.dispose();
    super.dispose();
  }

  void _setAutoScrollSpeed(double value) {
    _autoScrollSpeed = value.clamp(0.0, 1.0).toDouble();
    if (_autoScrollSpeed == 0) {
      _autoScrollTicker.stop();
    } else if (!_autoScrollTicker.isActive) {
      _lastAutoScrollElapsed = Duration.zero;
      _autoScrollTicker.start();
    }
    if (mounted) setState(() {});
  }

  void _autoScrollFrame(Duration elapsed) {
    final delta = elapsed - _lastAutoScrollElapsed;
    _lastAutoScrollElapsed = elapsed;
    final seconds = (delta.inMicroseconds / Duration.microsecondsPerSecond)
        .clamp(0.0, 0.05)
        .toDouble();
    final distance = _autoScrollSpeed * 20 * seconds;
    if (distance <= 0) return;

    if (widget.item.pdfAsset.isNotEmpty) {
      if (!_pdfController.isReady) return;
      final visible = _pdfController.visibleRect;
      final remaining = _pdfController.documentSize.height - visible.bottom;
      final maxDistance = remaining * _pdfController.currentZoom;
      if (maxDistance <= 0.5) {
        _setAutoScrollSpeed(0);
        return;
      }
      final step = distance.clamp(0.0, maxDistance).toDouble();
      final matrix = _pdfController.value.clone()
        ..translateByDouble(0, -step / _pdfController.currentZoom, 0, 1);
      _pdfController.value = matrix;
      if (step >= maxDistance) _setAutoScrollSpeed(0);
      return;
    }

    if (!sc.hasClients) return;
    final position = sc.position;
    final next = (position.pixels + distance)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    position.jumpTo(next);
    if (next >= position.maxScrollExtent) _setAutoScrollSpeed(0);
  }

  void _scrollChanged() {
    if (!mounted || !sc.hasClients || _scrollPageCount <= 1) return;
    final maxExtent = sc.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final current = (sc.offset / maxExtent * (_scrollPageCount - 1))
        .round()
        .clamp(0, _scrollPageCount - 1);
    if (current != index) setState(() => index = current);
  }

  void _pdfPageChanged(int? pageNumber) {
    if (pageNumber == null || _pdfPageCount == 0) return;
    final current = (pageNumber - 1).clamp(0, _pdfPageCount - 1);
    if (mounted && index != current) setState(() => index = current);
  }

  Widget _pdfBody(String asset) {
    final dark = app.dark;
    // These two Mawlid books have separately prepared, exact user-approved
    // light and dark borders. Do not invert or overlay their PDFs.
    final themedMawlid = widget.item.id == 'mankoos-mawlid' ||
        widget.item.id == 'mawlid-sharafal-anam';
    final pdfToOpen = themedMawlid && dark
        ? asset.replaceFirst('_light.pdf', '_dark.pdf')
        : asset;
    return Stack(
      children: [
        PdfViewer.asset(
          pdfToOpen,
          key: ValueKey(pdfToOpen),
          controller: _pdfController,
          params: PdfViewerParams(
            backgroundColor: dark ? Colors.black : Colors.grey,
            pageImageColorFilter:
                themedMawlid ? null : darkDocumentColorFilterFor(dark),
            // Match the existing dark-mode gold book framing on every PDF page,
            // not just Flutter-rendered text pages. This follows PDF zoom/scroll.
            pageOverlaysBuilder: dark && !themedMawlid
                ? (context, pageRect, page) => [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFEBCB84),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]
                : null,
            underflowAnchor: PdfPageAnchor.center,
            sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
              calculateInitialZoom: (_, __, fitPageScale, ___) => fitPageScale,
            ),
            onViewerReady: (document, controller) {
              if (!mounted) return;
              setState(() {
                _pdfPageCount = document.pages.length;
                index = ((controller.pageNumber ?? 1) - 1)
                    .clamp(0, _pdfPageCount - 1);
              });
            },
            onPageChanged: _pdfPageChanged,
            viewerOverlayBuilder: (context, size, handleLinkTap) => const [],
          ),
        ),
        if (_pdfPageCount > 1)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: AutoScrollSpeedSlider(
              value: _autoScrollSpeed,
              onChanged: _setAutoScrollSpeed,
            ),
          ),
      ],
    );
  }

  Future<void> _askReaderPage() async {
    final total = widget.item.pdfAsset.isNotEmpty
        ? _pdfPageCount
        : (paged ? widget.item.pages.length : _scrollPageCount);
    if (total < 1) return;
    final input = TextEditingController(text: '${index + 1}');
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1-$total'),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(int.tryParse(input.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    input.dispose();
    if (!mounted || selected == null || selected < 1 || selected > total) {
      return;
    }
    final next = selected - 1;
    if (widget.item.pdfAsset.isNotEmpty) {
      if (_pdfController.isReady) {
        await _pdfController.goToPage(pageNumber: selected);
      }
    } else if (paged && ctrl.hasClients) {
      ctrl.jumpToPage(next);
    } else if (sc.hasClients) {
      final totalPages = _scrollPageCount;
      final maxOffset = sc.position.maxScrollExtent;
      sc.jumpTo(totalPages <= 1 ? 0 : maxOffset * next / (totalPages - 1));
    }
    if (mounted) setState(() => index = next);
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
        final pageW = fitW;
        // Arabic book: pages turn right-to-left (reverse: true).
        return PageView.builder(
          controller: ctrl,
          reverse: true,
          physics: const PageScrollPhysics(),
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
                    child: PageSheet(
                        page: pages[i],
                        width: pageW,
                        dark: app.dark,
                        quran: true,
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
    return LayoutBuilder(
      builder: (context, c) {
        final availableWidth = (c.maxWidth - 20).clamp(0.0, double.infinity);
        final availableHeight = (c.maxHeight - 20).clamp(0.0, double.infinity);
        final fitW = availableWidth < availableHeight / kA4
            ? availableWidth
            : availableHeight / kA4;
        final pageW = fitW;
        if (pages.length == 1) {
          return Center(
            child: PageSheet(
              page: pages.single,
              width: pageW,
              dark: app.dark,
              quran: false,
              baseFont: bases.single,
            ),
          );
        }
        _scrollPageCount = pages.length;
        return Stack(
          children: [
            ListView.builder(
              controller: sc,
              itemCount: pages.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: PageSheet(
                    page: pages[i],
                    width: pageW,
                    dark: app.dark,
                    quran: false,
                    baseFont: bases[i],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AutoScrollSpeedSlider(
                value: _autoScrollSpeed,
                onChanged: _setAutoScrollSpeed,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final contentPages = item.hasContent
            ? item.pages.where((p) => !_isFooterOnlyPage(p)).toList()
            : [
                PageData([
                  Block(
                    type: 'text',
                    text:
                        (item.category == 'quran' || item.category == 'juz') &&
                                quranStatus.isNotEmpty
                            ? quranStatus
                            : 'Content not added yet',
                  )
                ])
              ];
        final isQuran = item.category == 'quran' || item.category == 'juz';
        final pages =
            isQuran ? contentPages : _withBookTitle(item, contentPages);
        final key =
            '${item.id}-${pages.fold<int>(0, (a, p) => a ^ p.plain.hashCode)}';
        List<PageData> shown = pages;
        List<double> bases;
        final hasText =
            pages.any((p) => p.blocks.any((b) => b.type != 'image'));
        final imageBasedBook = pages.isNotEmpty &&
            pages.every((p) =>
                p.blocks.isNotEmpty &&
                p.blocks.every((b) => b.type == 'image' || b.type == 'title'));
        if (!paged && pages.length > 1 && hasText && !imageBasedBook) {
          final r = reflowItem(key, pages, quran: isQuran);
          shown = r.pages;
          bases = List<double>.filled(shown.length, r.fs);
        } else {
          bases = itemFonts(key, pages, quran: isQuran);
        }
        final total = shown.length;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: item.pdfAsset.isEmpty
                ? Text(item.ar.isEmpty ? item.title : item.ar,
                    style: const TextStyle(
                        fontFamily: kArabicFont,
                        fontFamilyFallback: kFontFallback,
                        fontSize: 26,
                        fontWeight: FontWeight.w700))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.ar.isEmpty ? item.title : item.ar,
                          style: TextStyle(
                              color: app.dark ? const Color(0xFFEBCB84) : null,
                              fontFamily: kArabicFont,
                              fontFamilyFallback: kFontFallback,
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      if (_pdfPageCount > 1)
                        Text(
                          '${index + 1}/$_pdfPageCount',
                          style: const TextStyle(fontSize: 12, fontFamily: 'Arial', letterSpacing: 0),
                        ),
                    ],
                  ),
            actions: [
              IconButton(
                tooltip: 'Go to page',
                icon: const Icon(Icons.find_in_page_outlined),
                onPressed: _askReaderPage,
              ),
              themeToggleAction(),
              IconButton(
                tooltip: 'Bookmark',
                icon: Icon(app.isBookmarked(item.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border),
                onPressed: () => app.toggleBookmark(item.id),
              ),
            ],
          ),
          body: item.pdfAsset.isNotEmpty
              ? _pdfBody(item.pdfAsset)
              : paged
                  ? _pagedBody(shown, bases)
                  : _scrollBody(shown, bases),
          bottomNavigationBar: paged
              ? BottomAppBar(
                  child: Row(
                    children: [
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
                        onPressed:
                            index > 0 ? () => _go(index - 1, total) : null,
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}
