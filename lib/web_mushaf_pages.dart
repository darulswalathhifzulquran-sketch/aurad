import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'fast_web_page_image.dart';
import 'zoomable_page.dart';
import 'auto_scroll_speed_slider.dart';
import 'store.dart';

/// Lazy, vertical 604-page reader. Each leaf occupies one screen;
/// original Quran artwork is never stretched or cropped.
class WebMushafPages extends StatefulWidget {
  final int startPage;
  const WebMushafPages({super.key, required this.startPage});

  @override
  State<WebMushafPages> createState() => _WebMushafPagesState();
}

class _WebMushafPagesState extends State<WebMushafPages>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final Ticker _autoTicker;
  Duration _previousTick = Duration.zero;
  int _page = 1;
  double _pageExtent = 0;
  double _autoSpeed = 0;
  bool _initialPositioned = false;

  @override
  void initState() {
    super.initState();
    _page = widget.startPage.clamp(1, kMushafPageCount).toInt();
    _scroll.addListener(_trackPage);
    _autoTicker = createTicker(_autoScroll);
  }

  @override
  void dispose() {
    _autoTicker.dispose();
    _scroll.removeListener(_trackPage);
    _scroll.dispose();
    super.dispose();
  }

  void _trackPage() {
    if (!_scroll.hasClients || _pageExtent <= 0) return;
    final current = (_scroll.offset / _pageExtent).round()
        .clamp(0, kMushafPageCount - 1) + 1;
    if (current != _page && mounted) {
      setState(() => _page = current);
      app.prefs.setInt('mushaf_page', current);
    }
  }

  void _goto(int requested) {
    final target = requested.clamp(1, kMushafPageCount).toInt();
    if (mounted && target != _page) setState(() => _page = target);
    app.prefs.setInt('mushaf_page', target);
    if (_scroll.hasClients && _pageExtent > 0) {
      _scroll.jumpTo(((target - 1) * _pageExtent)
          .clamp(0.0, _scroll.position.maxScrollExtent).toDouble());
    }
  }

  void _setAutoSpeed(double value) {
    _autoSpeed = value;
    if (_autoSpeed == 0) {
      _autoTicker.stop();
    } else if (!_autoTicker.isActive) {
      _previousTick = Duration.zero;
      _autoTicker.start();
    }
    if (mounted) setState(() {});
  }

  void _autoScroll(Duration elapsed) {
    final dt = (elapsed - _previousTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    _previousTick = elapsed;
    if (_autoSpeed <= 0 || !_scroll.hasClients || dt <= 0) return;
    final position = _scroll.position;
    final next = (position.pixels + dt.clamp(0.0, 0.06) * _autoSpeed)
        .clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    position.jumpTo(next);
    if (next >= position.maxScrollExtent) _setAutoSpeed(0);
  }

  Future<void> _askPage() async {
    var input = '';
    final selection = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Go to Qur\'an page'),
        content: TextField(
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: '1 – 604'),
          onChanged: (value) => input = value,
          onSubmitted: (value) => Navigator.pop(c, int.tryParse(value)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(input)),
              child: const Text('Go')),
        ],
      ),
    );
    if (selection != null) _goto(selection);
  }

  String _asset(int page) =>
      'assets/quran_pages/page_${page.toString().padLeft(4, '0')}.jpg';

  // Display ONLY the original Mushaf page artwork. Its printed Surah/Juz
  // headings, Hizb marks and bottom page number are authoritative; no
  // separate Flutter labels or footers should duplicate them.
  Widget _sheet(int page, bool dark) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: ZoomablePage(
        key: ValueKey('quran-zoom-$page'),
        child: FastWebPageImage(
          asset: _asset(page),
          dark: dark,
          priority: page == _page,
        ),
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
          backgroundColor: dark ? Colors.black : Colors.white,
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('القرآن الكريم', textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: kArabicFont,
                      fontSize: 19, height: 1)),
                const Text("Holy Qur'an",
                  style: TextStyle(fontSize: 11, height: 1)),
                Text('Page $_page / $kMushafPageCount',
                  style: const TextStyle(fontSize: 10, height: 1)),
              ],
            ),
            actions: [
              IconButton(tooltip: 'Find page',
                icon: const Icon(Icons.find_in_page_outlined),
                onPressed: _askPage),
              // Place both page arrows together in the SAME top toolbar
              // used by other readers; do not create a second row/slider.
              IconButton(
                tooltip: 'Previous Qur\'an page',
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1 ? () => _goto(_page - 1) : null,
              ),
              IconButton(
                tooltip: 'Next Qur\'an page',
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < kMushafPageCount
                    ? () => _goto(_page + 1) : null,
              ),
              IconButton(tooltip: 'Dark / light',
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: app.toggleDark),
            ],

          ),
          body: LayoutBuilder(
            builder: (context, box) {
              final height = box.maxHeight;
              if (!_initialPositioned || _pageExtent != height) {
                _pageExtent = height;
                _initialPositioned = true;
                final wanted = _page;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_scroll.hasClients) return;
                  _scroll.jumpTo(((wanted - 1) * height)
                      .clamp(0.0, _scroll.position.maxScrollExtent).toDouble());
                });
              }
              return Stack(
                children: [
                  Positioned.fill(
                    child: ListView.builder(
                      controller: _scroll,
                      itemExtent: height,
                      cacheExtent: height * 0.4,
                      itemCount: kMushafPageCount,
                      itemBuilder: (context, index) =>
                          _sheet(index + 1, dark),
                    ),
                  ),
                  // Same automatic scroll-speed control as the book folders.
                  // Setting it to zero stops the scrolling immediately.
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: AutoScrollSpeedSlider(
                      value: _autoSpeed / 50,
                      onChanged: (value) => _setAutoSpeed(value * 50),
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
