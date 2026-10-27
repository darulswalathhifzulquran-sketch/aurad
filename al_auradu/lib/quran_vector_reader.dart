import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'mushaf.dart' show kSurahPage, kJuzPage;
import 'store.dart';

/// Original Hafs/Madinah 1441 vector pages, converted without OCR or retyping.
///
/// This asset is produced from the owner's 604 official AI pages by
/// tool/import_vector_quran.py. NEVER use the 624-page image-scan quran.pdf
/// for these 604-page Surah/Juz indices.
const String kVerifiedVectorMushafAsset = 'assets/books/quran_vector_604.pdf';
const int kExpectedVectorMushafPages = 604;

/// Navigation is enabled only after a 604-page PDF is present.
/// The exact Surah/Juz boundaries must ALSO be visually approved before merge.
int? quranStartPageForId(String id) {
  final parts = id.split('-');
  if (parts.length != 2) return null;
  final n = int.tryParse(parts.last);
  if (n == null) return null;
  if (parts.first == 'quran' && n >= 1 && n <= 114) {
    return kSurahPage[n - 1];
  }
  if (parts.first == 'juz' && n >= 1 && n <= 30) {
    return kJuzPage[n - 1];
  }
  return null;
}

class QuranVectorReader extends StatefulWidget {
  const QuranVectorReader({super.key, required this.itemId});

  final String itemId;

  @override
  State<QuranVectorReader> createState() => _QuranVectorReaderState();
}

class _QuranVectorReaderState extends State<QuranVectorReader> {
  final PdfViewerController _controller = PdfViewerController();
  bool _ready = false;
  int? _total;
  int _page = 1;
  Timer? _scrollTimer;
  bool _autoScroll = false;
  double _scrollSpeed = 0.8;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoScroll() {
    _scrollTimer?.cancel();
    setState(() => _autoScroll = !_autoScroll);
    if (!_autoScroll) return;
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || !_controller.isReady) return;
      final viewport = _controller.visibleRect;
      final maximum = _controller.documentSize.height - viewport.height;
      if (viewport.top >= maximum) {
        _scrollTimer?.cancel();
        if (mounted) setState(() => _autoScroll = false);
        return;
      }
      _controller.goToPosition(
        documentOffset: Offset(viewport.left,
          (viewport.top + _scrollSpeed).clamp(0.0, maximum < 0 ? 0.0 : maximum)),
        duration: Duration.zero,
      );
    });
  }

  void _viewerReady(PdfDocument doc, PdfViewerController controller) {
    if (!mounted) return;
    final count = doc.pages.length;
    setState(() {
      _ready = true;
      _total = count;
    });
    // Do not ever jump to a potentially wrong Surah/Juz in a different
    // edition or a PDF with prefatory pages.
    final start = quranStartPageForId(widget.itemId);
    if (count == kExpectedVectorMushafPages && start != null) {
      controller.goToPage(pageNumber: start);
      setState(() => _page = start);
    }
  }

  void _pageChanged(int? pageNumber) {
    if (!mounted || pageNumber == null) return;
    setState(() => _page = pageNumber);
    app.prefs.setInt('quran_vector_last_page', pageNumber);
  }

  void _step(int amount) {
    final total = _total;
    if (!_ready || total == null) return;
    _controller.goToPage(pageNumber: (_page + amount).clamp(1, total));
  }

  Future<void> _findPage() async {
    final total = _total;
    if (!_ready || total == null) return;

    final input = TextEditingController(text: _page.toString());
    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Quran page'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1–$total'),
          onSubmitted: (value) => Navigator.of(ctx).pop(int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(input.text)),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    // Do not dispose the controller synchronously while a dialog closing
    // animation could still be using its editable text widget.
    if (!mounted || page == null || page < 1 || page > total) return;
    _controller.goToPage(pageNumber: page);
  }

  Widget _pageArrow(IconData icon, String tooltip, VoidCallback action) {
    return Material(
      color: const Color(0xB80A203C),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: _ready ? action : null,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = app.dark;
    return Scaffold(
      backgroundColor: dark ? Colors.black : const Color(0xFFE6E5DE),
      appBar: AppBar(
        title: const Text(
          'القرآن الكريم',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: kArabicFont, fontSize: 23),
        ),
        actions: [
          IconButton(
            tooltip: _autoScroll ? 'Pause scroll' : 'Start slow scroll',
            onPressed: _ready ? _toggleAutoScroll : null,
            icon: Icon(_autoScroll ? Icons.pause_circle_outline : Icons.play_circle_outline),
          ),
          IconButton(
            tooltip: 'Open Quran page number',
            onPressed: _ready ? _findPage : null,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Dark or light',
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(app.toggleDark),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_ready && _total != kExpectedVectorMushafPages)
            MaterialBanner(
              content: Text(
                'This PDF has $_total pages instead of 604. '
                'Surah and Juz jumps are disabled to prevent mistakes.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          if (_ready)
            SizedBox(height: 36, child: Row(children: [
              const SizedBox(width: 8),
              const Text('Scroll speed'),
              Expanded(child: Slider(value: _scrollSpeed, min: 0.2, max: 2.0,
                onChanged: (v) => setState(() => _scrollSpeed = v))),
            ])),
          Expanded(
            child: Stack(
              children: [
                PdfViewer.asset(
                  kVerifiedVectorMushafAsset,
                  useProgressiveLoading: true,
                  controller: _controller,
                  initialPageNumber: 1,
                  params: PdfViewerParams(
                    backgroundColor:
                        dark ? Colors.black : const Color(0xFFE6E5DE),
                    margin: 8,
                    calculateInitialZoom:
                        (document, controller, fitZoom, coverZoom) => fitZoom,
                    limitRenderingCache: true,
                    onViewerReady: _viewerReady,
                    onPageChanged: _pageChanged,
                    errorBannerBuilder: (context, error, stack, doc) =>
                        const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Verified Quran PDF not added yet. '
                          'The 604-page source must be imported and checked.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 3,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _pageArrow(Icons.chevron_left, 'Next page',
                        () => _step(1)),
                  ),
                ),
                Positioned(
                  right: 3,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _pageArrow(Icons.chevron_right, 'Previous page',
                        () => _step(-1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
