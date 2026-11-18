import 'package:flutter/material.dart';
import 'fast_web_page_image.dart';
import 'package:flutter/scheduler.dart';
import 'auto_scroll_speed_slider.dart';
import 'models.dart';
import 'store.dart';

// Fixed counts for the approved PDFs prevent waiting on, or accidentally
// using the old empty web_books_manifest.json bundled in a cached build.
const Map<String, int> kWebBookPageCounts = {
  'baith-3': 2,
  'mawlid-sharafal-anam': 30,
  'mankoos-mawlid': 13,
  'mawlid-2': 25,
  'swalath-saadha': 1,
  'swalath-3': 2,
  'swalath-4': 1,
  'dua-4': 3,
  'majlisunnoor-1': 17,
};

/// Purpose-built Flutter Web reader (NO native PDF plugin or toolbar).
/// Images are generated from each unchanged original PDF; original printed
/// numbers, footer, Arabic text and border are part of every page image.
/// Only visible pages load. Theme switches affect pixels immediately.
class WebBookReader extends StatefulWidget {
  final Item item;
  const WebBookReader({super.key, required this.item});

  @override
  State<WebBookReader> createState() => _WebBookReaderState();
}

class _WebBookReaderState extends State<WebBookReader>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker;
  Duration _previousTick = Duration.zero;
  int _page = 1;
  late final int _count;
  double _extent = 0;
  double _speed = 0;
  bool _positioned = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_autoScroll);
    _scroll.addListener(_onScroll);
    _count = kWebBookPageCounts[widget.item.id] ?? 0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_extent <= 0 || !_scroll.hasClients || _count <= 0) return;
    final p = (_scroll.offset / _extent).round().clamp(0, _count - 1) + 1;
    if (p != _page && mounted) setState(() => _page = p);
  }

  void _goto(int p) {
    if (_count < 1) return;
    final target = p.clamp(1, _count).toInt();
    if (target != _page) setState(() => _page = target);
    if (_scroll.hasClients && _extent > 0) {
      _scroll.jumpTo(((target - 1) * _extent).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      ).toDouble());
    }
  }

  void _setSpeed(double value) {
    _speed = value.clamp(0.0, 1.0).toDouble();
    if (_speed == 0) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _previousTick = Duration.zero;
      _ticker.start();
    }
    setState(() {});
  }

  void _autoScroll(Duration elapsed) {
    final delta = elapsed - _previousTick;
    _previousTick = elapsed;
    if (!_scroll.hasClients || _speed == 0) return;
    final seconds = (delta.inMicroseconds / Duration.microsecondsPerSecond)
        .clamp(0.0, 0.05).toDouble();
    final pos = _scroll.position;
    final next = (pos.pixels + seconds * _speed * 35)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
    _scroll.jumpTo(next);
    if (next >= pos.maxScrollExtent) _setSpeed(0);
  }

  Future<void> _askPage() async {
    if (_count < 1) return;
    var text = '';
    final chosen = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '1 – $_count'),
          onChanged: (s) => text = s,
          onSubmitted: (s) => Navigator.pop(c, int.tryParse(s)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(text)),
              child: const Text('Go')),
        ],
      ),
    );
    if (chosen != null) _goto(chosen);
  }

  Widget _pageImage(int page, double width, double height, bool dark) {
    final file = 'assets/web_books/${widget.item.id}_page_${page.toString().padLeft(4, '0')}.jpg';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: FastWebPageImage(asset: file, dark: dark),
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
                Text(widget.item.ar.isNotEmpty ? widget.item.ar : widget.item.title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: kArabicFont,
                                           fontSize: 21)),
                if (_count > 1)
                  Text('$_page / $_count',
                       style: const TextStyle(fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Go to page',
                icon: const Icon(Icons.find_in_page_outlined),
                onPressed: _askPage,
              ),
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1 ? () => _goto(_page - 1) : null,
              ),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < _count ? () => _goto(_page + 1) : null,
              ),
              IconButton(
                tooltip: 'Dark / Light',
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: app.toggleDark,
              ),
              IconButton(
                tooltip: 'Bookmark',
                icon: Icon(app.isBookmarked(widget.item.id)
                    ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => app.toggleBookmark(widget.item.id),
              ),
            ],
          ),
          body: _count == 0
              ? const Center(child: Text('This book is not installed.'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const ratio = 1.4142;
                    final width = (constraints.maxWidth - 52)
                        .clamp(120.0, 720.0)
                        .toDouble()
                        .clamp(0.0, constraints.maxHeight / ratio)
                        .toDouble();
                    final height = width * ratio;
                    final itemExtent = height + 8;
                    if (!_positioned || itemExtent != _extent) {
                      final wantedPage = _page;
                      _extent = itemExtent;
                      _positioned = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || !_scroll.hasClients) return;
                        _scroll.jumpTo(((wantedPage - 1) * _extent).clamp(
                          _scroll.position.minScrollExtent,
                          _scroll.position.maxScrollExtent,
                        ).toDouble());
                      });
                    }
                    return Stack(
                      children: [
                        ListView.builder(
                          itemCount: _count,
                          itemExtent: itemExtent,
                          cacheExtent: itemExtent * 2,
                          controller: _scroll,
                          itemBuilder: (context, i) =>
                              _pageImage(i + 1, width, height, dark),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: AutoScrollSpeedSlider(
                            value: _speed,
                            onChanged: _setSpeed,
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
