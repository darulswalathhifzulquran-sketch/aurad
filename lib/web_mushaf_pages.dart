import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'auto_scroll_speed_slider.dart';
import 'fast_web_page_image.dart';
import 'zoomable_page.dart';
import 'store.dart';

/// Exactly one ORIGINAL Quran page per screen. Printed surah, juz,
/// hizb and page number are all preserved in the page artwork.
class WebMushafPages extends StatefulWidget {
  final int startPage;
  const WebMushafPages({super.key, required this.startPage});

  @override
  State<WebMushafPages> createState() => _WebMushafPagesState();
}

class _WebMushafPagesState extends State<WebMushafPages>
    with SingleTickerProviderStateMixin {
  late final PageController _pages;
  late final Ticker _ticker;
  Duration _previous = Duration.zero;
  double _speed = 0;
  double _accumulated = 0;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.startPage.clamp(1, kMushafPageCount).toInt();
    _pages = PageController(initialPage: _page - 1);
    _ticker = createTicker(_autoAdvance);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _remember(int page) {
    if (_page != page && mounted) setState(() => _page = page);
    app.prefs.setInt('mushaf_page', page);
  }

  void _goTo(int page) {
    if (!_pages.hasClients) return;
    final next = page.clamp(1, kMushafPageCount).toInt();
    _pages.animateToPage(
      next - 1,
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOut,
    );
  }

  void _setSpeed(double value) {
    _speed = value.clamp(0.0, 1.0).toDouble();
    _accumulated = 0;
    _previous = Duration.zero;
    if (_speed == 0) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
    setState(() {});
  }

  void _autoAdvance(Duration elapsed) {
    final seconds = (elapsed - _previous).inMicroseconds /
        Duration.microsecondsPerSecond;
    _previous = elapsed;
    if (_speed <= 0 || !_pages.hasClients || seconds <= 0) return;
    _accumulated += seconds.clamp(0.0, 0.1);
    if (_accumulated >= 20.0 - (_speed * 17.0)) {
      _accumulated = 0;
      if (_page < kMushafPageCount) {
        _goTo(_page + 1);
      } else {
        _setSpeed(0);
      }
    }
  }

  Future<void> _askPage() async {
    String input = '';
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go to Quran page'),
        content: TextField(
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: '1 – 604'),
          onChanged: (v) => input = v,
          onSubmitted: (v) => Navigator.pop(dialogContext, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, int.tryParse(input)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (selected != null) _goTo(selected);
  }

  String _asset(int page) =>
      'assets/quran_pages/page_' + page.toString().padLeft(4, '0') + '.jpg';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final dark = app.dark;
        return Scaffold(
          backgroundColor: dark ? Colors.black : Colors.white,
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'القرآن الكريم',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: kArabicFont, fontSize: 20, height: 1.0),
                ),
                const Text("Holy Qur'an",
                    style: TextStyle(fontSize: 11, height: 1.0)),
                Text('Page ' + _page.toString() + ' / ' + kMushafPageCount.toString(),
                    style: const TextStyle(fontSize: 10, height: 1.0)),
              ],
            ),
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
          body: LayoutBuilder(
            builder: (context, bounds) {
              // A complete Quran leaf fills the reading viewport, inside
              // a slim outer frame. Keep the original image aspect ratio,
              // Arabic text, printed ornamentation and page numbers intact.
              final width = (bounds.maxWidth - 12).clamp(1.0, double.infinity).toDouble();
              final height = (bounds.maxHeight - 12).clamp(1.0, double.infinity).toDouble();
              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: dark ? Colors.black : Colors.white,
                          border: Border.all(
                            color: dark
                                ? const Color(0xFFCDAA65)
                                : const Color(0xFFB18A45),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: ClipRect(
                          child: PageView.builder(
                            controller: _pages,
                            itemCount: kMushafPageCount,
                            onPageChanged: (index) => _remember(index + 1),
                            itemBuilder: (context, index) => Center(
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: ZoomablePage(
                                  key: ValueKey('zoom-quran-$index'),
                                  child: FastWebPageImage(
                                    asset: _asset(index + 1),
                                    dark: dark,
                                    priority: index == _page - 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: AutoScrollSpeedSlider(
                      value: _speed,
                      onChanged: _setSpeed,
                    ),
                  ),
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton.filledTonal(
                        tooltip: 'Previous page',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _page > 1 ? () => _goTo(_page - 1) : null,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 42,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton.filledTonal(
                        tooltip: 'Next page',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _page < kMushafPageCount
                            ? () => _goTo(_page + 1)
                            : null,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
