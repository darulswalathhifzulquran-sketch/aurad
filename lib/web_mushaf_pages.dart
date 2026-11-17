import 'package:flutter/material.dart';
import 'fast_web_page_image.dart';
import 'package:flutter/scheduler.dart';
import 'auto_scroll_speed_slider.dart';
import 'store.dart';

/// Flutter Web Quran viewer: loads just the visible original Mushaf page
/// images instead of waiting for the entire 604-page PDF and PDFium WASM.
/// Assets are produced from the *unchanged* quran.pdf using the converter.
class WebMushafPages extends StatefulWidget {
  final int startPage;
  const WebMushafPages({super.key, required this.startPage});

  @override
  State<WebMushafPages> createState() => _WebMushafPagesState();
}

class _WebMushafPagesState extends State<WebMushafPages>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _speed = 0;
  double _extent = 0;
  bool _initialPositionApplied = false;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.startPage.clamp(1, 604).toInt();
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
    _ticker = createTicker(_autoScroll);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_extent <= 0 || !_scroll.hasClients) return;
    final next = (_scroll.offset / _extent).round().clamp(0, 603) + 1;
    if (next != _page && mounted) {
      setState(() => _page = next);
      app.prefs.setInt('mushaf_page', next);
    }
  }

  void _moveTo(int requested) {
    final next = requested.clamp(1, 604).toInt();
    if (next != _page) setState(() => _page = next);
    app.prefs.setInt('mushaf_page', next);
    if (_scroll.hasClients && _extent > 0) {
      _scroll.jumpTo(
        ((next - 1) * _extent).clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        ).toDouble(),
      );
    }
  }

  void _setSpeed(double next) {
    _speed = next.clamp(0.0, 1.0).toDouble();
    if (_speed == 0) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    setState(() {});
  }

  void _autoScroll(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    if (!_scroll.hasClients || _speed == 0) return;
    final seconds = (delta.inMicroseconds / Duration.microsecondsPerSecond)
        .clamp(0.0, 0.05).toDouble();
    final position = _scroll.position;
    final next = (position.pixels + seconds * _speed * 35.0)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scroll.jumpTo(next);
    if (next >= position.maxScrollExtent) _setSpeed(0);
  }

  Future<void> _askPage() async {
    String entered = '';
    final p = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Go to Quran page'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '1 – 604'),
          onChanged: (v) => entered = v,
          onSubmitted: (v) => Navigator.pop(c, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c),
                     child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(entered)),
                       child: const Text('Go')),
        ],
      ),
    );
    if (p != null) _moveTo(p);
  }

  String _pageAsset(int p) =>
      'assets/quran_pages/page_${p.toString().padLeft(4, '0')}.jpg';

  Widget _imagePage(int p, double w, double h, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: SizedBox(
          width: w,
          height: h,
          // Display the original Qur'an page artwork and print colors,
          // without the newer full-page negative/green night effect.
          // Changing the app theme never re-renders Qur'an letters.
          child: FastWebPageImage(asset: _pageAsset(p), dark: false),
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
                const Text('رياض الأذكار',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'Amiri', fontSize: 19)),
                Text('Page $_page / 604',
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
                tooltip: 'Dark / Light',
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: app.toggleDark,
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              const ratio = 1.4142;
              final pageW = (constraints.maxWidth - 52)
                  .clamp(120.0, 720.0)
                  .toDouble()
                  .clamp(0.0, constraints.maxHeight / ratio)
                  .toDouble();
              final pageH = pageW * ratio;
              final itemExtent = pageH + 8;
              if (!_initialPositionApplied || _extent != itemExtent) {
                final wanted = _initialPositionApplied
                    ? _page
                    : widget.startPage.clamp(1, 604);
                _extent = itemExtent;
                _initialPositionApplied = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_scroll.hasClients) return;
                  _scroll.jumpTo(((wanted - 1) * _extent).clamp(
                    _scroll.position.minScrollExtent,
                    _scroll.position.maxScrollExtent,
                  ).toDouble());
                });
              }
              return Stack(
                children: [
                  ListView.builder(
                    controller: _scroll,
                    itemExtent: itemExtent,
                    itemCount: 604,
                    cacheExtent: itemExtent * 2,
                    itemBuilder: (context, i) =>
                        _imagePage(i + 1, pageW, pageH, dark),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: AutoScrollSpeedSlider(
                      value: _speed,
                      onChanged: _setSpeed,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 4,
                    child: Center(
                      child: IconButton.filledTonal(
                        tooltip: 'Previous page',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _page > 1 ? () => _moveTo(_page - 1) : null,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 42,
                    child: Center(
                      child: IconButton.filledTonal(
                        tooltip: 'Next page',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _page < 604 ? () => _moveTo(_page + 1) : null,
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
