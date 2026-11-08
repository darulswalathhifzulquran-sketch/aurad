import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdfrx/pdfrx.dart';
import 'auto_scroll_speed_slider.dart';
import 'store.dart';

/// First page (Madinah Mushaf, 604 pages) of every surah.
const List<int> kSurahPage = [
  1,
  2,
  50,
  77,
  106,
  128,
  151,
  177,
  187,
  208,
  221,
  235,
  249,
  255,
  262,
  267,
  282,
  293,
  305,
  312,
  322,
  332,
  342,
  350,
  359,
  367,
  377,
  385,
  396,
  404,
  411,
  415,
  418,
  428,
  434,
  440,
  446,
  453,
  458,
  467,
  477,
  483,
  489,
  496,
  499,
  502,
  507,
  511,
  515,
  518,
  520,
  523,
  526,
  528,
  531,
  534,
  537,
  542,
  545,
  549,
  551,
  553,
  554,
  556,
  558,
  560,
  562,
  564,
  566,
  568,
  570,
  572,
  574,
  575,
  577,
  578,
  580,
  582,
  583,
  585,
  586,
  587,
  587,
  589,
  590,
  591,
  591,
  592,
  593,
  594,
  595,
  595,
  596,
  596,
  597,
  597,
  598,
  598,
  599,
  599,
  600,
  600,
  601,
  601,
  601,
  602,
  602,
  602,
  603,
  603,
  603,
  604,
  604,
  604,
];

/// First page of every juz.
const List<int> kJuzPage = [
  1,
  22,
  42,
  62,
  82,
  102,
  121,
  142,
  162,
  182,
  201,
  222,
  242,
  262,
  282,
  302,
  322,
  342,
  362,
  382,
  402,
  422,
  442,
  462,
  482,
  502,
  522,
  542,
  562,
  582,
];

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

class MushafScreen extends StatefulWidget {
  final int startPage;
  const MushafScreen({super.key, this.startPage = 1});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen>
    with SingleTickerProviderStateMixin {
  final PdfViewerController _pdfController = PdfViewerController();
  // Keep delegate identity stable across theme changes: pdfrx checks
  // delegate equality when deciding whether to rebuild its PDF layout.
  final PdfViewerSizeDelegateProviderLegacy _quranSizeDelegate =
      PdfViewerSizeDelegateProviderLegacy(
    calculateInitialZoom: (_, __, fitPageScale, ___) => fitPageScale,
  );
  late final Ticker _autoScrollTicker;
  Duration _lastAutoScrollElapsed = Duration.zero;
  double _autoScrollSpeed = 0;
  late int page;

  @override
  void initState() {
    super.initState();
    page = widget.startPage.clamp(1, mushafCount).toInt();
    _autoScrollTicker = createTicker(_autoScrollFrame);
  }

  @override
  void dispose() {
    _autoScrollTicker.dispose();
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
    if (!_pdfController.isReady) return;
    final delta = elapsed - _lastAutoScrollElapsed;
    _lastAutoScrollElapsed = elapsed;
    final seconds = (delta.inMicroseconds / Duration.microsecondsPerSecond)
        .clamp(0.0, 0.05)
        .toDouble();
    final speed = _autoScrollSpeed * 20;
    if (seconds <= 0 || speed <= 0) return;

    final visible = _pdfController.visibleRect;
    final documentSize = _pdfController.documentSize;
    final remaining = documentSize.height - visible.bottom;
    if (remaining <= 1 / _pdfController.currentZoom) {
      _setAutoScrollSpeed(0);
      return;
    }
    final distance = (speed * seconds)
        .clamp(
          0.0,
          remaining * _pdfController.currentZoom,
        )
        .toDouble();
    final matrix = _pdfController.value.clone()
      ..translateByDouble(0, -distance / _pdfController.currentZoom, 0, 1);
    _pdfController.value = matrix;
    if (distance >= remaining * _pdfController.currentZoom) {
      _setAutoScrollSpeed(0);
    }
  }

  void _goto(int p, {bool animate = true, Duration? duration}) {
    final t = p.clamp(1, mushafCount).toInt();
    if (mounted && page != t) {
      setState(() => page = t);
    }
    app.prefs.setInt('mushaf_page', t);
    if (_pdfController.isReady) {
      unawaited(_pdfController.goToPage(
        pageNumber: t + kQuranPdfFirstPage - 1,
        duration: duration ??
            (animate ? const Duration(milliseconds: 220) : Duration.zero),
      ));
    }
  }

  void _step(int d) {
    _goto(page + d);
  }

  void _pageChanged(int? pdfPageNumber) {
    if (pdfPageNumber == null) return;
    final lastPdfPage = kQuranPdfFirstPage + mushafCount - 1;
    if (pdfPageNumber < kQuranPdfFirstPage) {
      _goto(1, animate: false);
      return;
    }
    if (pdfPageNumber > lastPdfPage) {
      _goto(mushafCount, animate: false);
      return;
    }
    final quranPage = pdfPageNumber - kQuranPdfFirstPage + 1;
    if (quranPage == page) return;
    setState(() => page = quranPage);
    app.prefs.setInt('mushaf_page', quranPage);
  }

  void _viewerReady(PdfDocument document, PdfViewerController controller) {
    final requiredPageCount = kQuranPdfFirstPage + mushafCount - 1;
    if (document.pages.length < requiredPageCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The original Quran PDF has ${document.pages.length} pages; '
            'at least $requiredPageCount are required.',
          ),
        ),
      );
      return;
    }
    final initialPdfPageNumber = page + kQuranPdfFirstPage - 1;
    if (controller.pageNumber == initialPdfPageNumber) {
      _pageChanged(controller.pageNumber);
    } else {
      _goto(page, animate: false);
    }
  }

  Future<void> _askPage() async {
    var pageInput = '';
    final v = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - $mushafCount'),
          onChanged: (s) => pageInput = s,
          onSubmitted: (s) => Navigator.pop(c, int.tryParse(s)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, int.tryParse(pageInput)),
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

  Widget _sideButton(IconData icon, String tip, VoidCallback onTap, bool dark) {
    return Material(
      color: dark ? Colors.white24 : Colors.black26,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tip,
        iconSize: 30,
        color: Colors.white,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
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
            // Mushaf page labels belong to the original page artwork.
            // Avoid duplicating its Surah/Juz/page information in the app bar.
            title: const Text('رياض الأذكار'),
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
          body: Stack(
            children: [
              ColorFiltered(
                // Both themes display the identical Quran PDF: same 604
                // pages, glyphs, ayah ornaments, and line breaks.
                // Dark mode inverts display pixels only; PDF bytes stay intact.
                colorFilter: ColorFilter.matrix(dark
                    ? const <double>[
                        -1, 0, 0, 0, 255,
                        0, -1, 0, 0, 255,
                        0, 0, -1, 0, 255,
                        0, 0, 0, 1, 0,
                      ]
                    : const <double>[
                        1, 0, 0, 0, 0,
                        0, 1, 0, 0, 0,
                        0, 0, 1, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: PdfViewer.asset(
                kQuranPdfAsset,
                key: const ValueKey('quran-single-pdf-viewer'),
                controller: _pdfController,
                initialPageNumber: page + kQuranPdfFirstPage - 1,
                params: PdfViewerParams(
                  // Always white INSIDE ColorFiltered. In dark mode the
                  // entire PDF viewer (including its empty margins) inverts
                  // to true black. Keeping these parameters constant also
                  // prevents pdfrx from reloading when the theme changes.
                  backgroundColor: Colors.white,
                  pageDropShadow: null,
                  margin: 8,
                  pageAnchor: PdfPageAnchor.topCenter,
                  underflowAnchor: PdfPageAnchor.topCenter,
                  sizeDelegateProvider: _quranSizeDelegate,
                  onViewerReady: _viewerReady,
                  onPageChanged: _pageChanged,
                  viewerOverlayBuilder: (context, size, handleLinkTap) =>
                      const [],
                  errorBannerBuilder:
                      (context, error, stackTrace, documentRef) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not open the original Quran PDF: $error',
                        textAlign: TextAlign.center,
                      ),
                    ),
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
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _sideButton(
                    Icons.chevron_left,
                    'Next page',
                    () => _step(1),
                    dark,
                  ),
                ),
              ),
              Positioned(
                right: 52,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _sideButton(
                    Icons.chevron_right,
                    'Previous page',
                    () => _step(-1),
                    dark,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
