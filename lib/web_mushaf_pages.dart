import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'fast_web_page_image.dart';
import 'zoomable_page.dart';
import 'mushaf.dart' show surahAtPage, juzAtPage;
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

  String _surahName(int page) {
    final no = surahAtPage(page);
    for (final item in app.items) {
      if (item.category == 'quran' && item.id.endsWith('-$no')) {
        return item.ar;
      }
    }
    return 'سورة $no';
  }

  Widget _sheet(int page, double width, double height, bool dark) {
    final ink = dark ? const Color(0xFFFFE6AF) : const Color(0xFF163C31);
    final green = dark ? const Color(0xFF14372E) : const Color(0xFFC8EAD0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: green,
          border: Border.all(
            color: dark ? const Color(0xFFD1BD86) : const Color(0xFF86BD98),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 43,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_surahName(page),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: kArabicFont,
                            fontSize: 17, color: ink)),
                    ),
                    const SizedBox(width: 8),
                    Text('الجزء ${juzAtPage(page)}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: kArabicFont,
                          fontSize: 17, color: ink)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: ZoomablePage(
                  key: ValueKey('quran-zoom-$page'),
                  child: FastWebPageImage(
                    asset: _asset(page),
                    dark: dark,
                    priority: page == _page,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: Center(
                child: Text('$page / $kMushafPageCount',
                  style: TextStyle(color: ink, fontSize: 14,
                      fontWeight: FontWeight.w600)),
              ),
            ),
          ],
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
              PopupMenuButton<double>(
                tooltip: 'Automatic scrolling speed',
                icon: Icon(_autoSpeed > 0 ? Icons.pause_circle
                    : Icons.play_circle_outline),
                onSelected: _setAutoSpeed,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: Text('Stop auto-scroll')),
                  PopupMenuItem(value: 12, child: Text('Slow')),
                  PopupMenuItem(value: 28, child: Text('Medium')),
                  PopupMenuItem(value: 50, child: Text('Fast')),
                ],
              ),
              IconButton(tooltip: 'Dark / light',
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: app.toggleDark),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                      iconSize: 18, icon: const Icon(Icons.chevron_left),
                      onPressed: _page > 1 ? () => _goto(_page - 1) : null),
                    Expanded(
                      child: Slider(
                        value: _page.toDouble(),
                        min: 1, max: kMushafPageCount.toDouble(),
                        divisions: kMushafPageCount - 1,
                        onChanged: (value) => _goto(value.round()),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next page',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                      iconSize: 18, icon: const Icon(Icons.chevron_right),
                      onPressed: _page < kMushafPageCount
                          ? () => _goto(_page + 1) : null),
                  ],
                ),
              ),
            ),
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
              return ListView.builder(
                controller: _scroll,
                itemExtent: height,
                cacheExtent: height * 0.4,
                itemCount: kMushafPageCount,
                itemBuilder: (context, index) =>
                    _sheet(index + 1, box.maxWidth, height, dark),
              );
            },
          ),
        );
      },
    );
  }
}
