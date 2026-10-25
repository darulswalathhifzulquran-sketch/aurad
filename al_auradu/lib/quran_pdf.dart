import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'mushaf.dart';
import 'store.dart';

/// Native PDFium-based 604-page Quran viewer.
///
/// Uses the existing original (Git LFS) quran.pdf, not the old low-resolution
/// assets/quran/*.webp page screenshots. No Quran text is synthesized.
///
/// Surah/Juz start-page mappings below belong to the standard 604-page
/// Madinah layout. Only apply them after the PDF page count is verified.
/// Page count alone DOES NOT prove that the edition matches these mappings:
/// release must also be visually reviewed by the owner.
class QuranPdfScreen extends StatefulWidget {
  final int startPage;

  const QuranPdfScreen({super.key, required this.startPage});

  @override
  State<QuranPdfScreen> createState() => _QuranPdfScreenState();
}

class _QuranPdfScreenState extends State<QuranPdfScreen> {
  static const expectedPages = 604;
  final PdfViewerController controller = PdfViewerController();
  int currentPage = 1;
  int? actualPageCount;
  bool viewerReady = false;

  void _viewerReady(PdfDocument document, PdfViewerController readyController) {
    final n = document.pages.length;
    if (!mounted) return;
    setState(() {
      actualPageCount = n;
      viewerReady = true;
      currentPage = 1;
    });
    // A different page count means page numbers are not reliable.
    // Keep page 1 visible and show a warning instead of jumping to a
    // potentially different Surah/Juz.
    if (n == expectedPages && widget.startPage != 1) {
      readyController.goToPage(
        pageNumber: widget.startPage.clamp(1, expectedPages),
      );
    }
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || !mounted) return;
    setState(() => currentPage = pageNumber);
    app.prefs.setInt('quran_last_page', pageNumber);
  }

  void _step(int delta) {
    if (!viewerReady) return;
    final count = actualPageCount ?? expectedPages;
    final p = (currentPage + delta).clamp(1, count);
    controller.goToPage(pageNumber: p);
  }

  Future<void> _goToPage() async {
    if (!viewerReady) return;
    final count = actualPageCount ?? expectedPages;
    final textController =
        TextEditingController(text: currentPage.toString());
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Quran page'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 – $count'),
          onSubmitted: (s) => Navigator.pop(context, int.tryParse(s)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(textController.text)),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (choice != null && choice >= 1 && choice <= count && mounted) {
      controller.goToPage(pageNumber: choice);
    }
  }

  Widget _pageButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Material(
      color: const Color(0xBB1E3857),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: viewerReady ? onPressed : null,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verifiedPageCount = actualPageCount == expectedPages;
    return Scaffold(
      backgroundColor: app.dark ? Colors.black : const Color(0xFFDFE3E8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('القرآن الكريم',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 22, fontFamily: kArabicFont)),
            Text(
              'Page $currentPage / ${actualPageCount ?? expectedPages}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Go to page',
            onPressed: viewerReady ? _goToPage : null,
            icon: const Icon(Icons.find_in_page_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (viewerReady && !verifiedPageCount)
            MaterialBanner(
              content: Text(
                'This PDF has $actualPageCount pages, not 604. '
                'Surah/Juz shortcuts are paused until its edition is checked.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                )
              ],
            ),
          Expanded(
            child: Stack(
              children: [
                PdfViewer.asset(
                  'quran.pdf',
                  // pdfrx renders pages on demand, allowing pinch-zoom and
                  // continuous vertical scrolling with no extra zoom slider.
                  useProgressiveLoading: true,
                  controller: controller,
                  initialPageNumber: 1,
                  params: PdfViewerParams(
                    backgroundColor: app.dark
                        ? Colors.black
                        : const Color(0xFFE7E7E7),
                    margin: 8,
                    limitRenderingCache: true,
                    onViewerReady: _viewerReady,
                    onPageChanged: _onPageChanged,
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _pageButton(
                        Icons.chevron_left, 'Next page', () => _step(1)),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _pageButton(Icons.chevron_right,
                        'Previous page', () => _step(-1)),
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

/// Standard Madinah-604 book start pages supplied by the original app.
/// Keeping these central prevents unrelated folders from being modified.
int quranStartPageForId(String id) {
  final parts = id.split('-');
  if (parts.length != 2) return 1;
  final n = int.tryParse(parts.last) ?? 1;
  if (parts.first == 'quran' && n >= 1 && n <= 114) {
    return kSurahPage[n - 1];
  }
  if (parts.first == 'juz' && n >= 1 && n <= 30) {
    return kJuzPage[n - 1];
  }
  return 1;
}
