import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app_theme.dart';
import 'auto_scroll_speed_slider.dart';
import 'mushaf.dart';
import 'store.dart';

/// Offline, line-locked Quran prototype. Its source is imported separately.
/// The verified original PDF remains the fallback until the imported data
/// and its publication rights have been checked page by page.
class QuranLineReader extends StatefulWidget {
  final int startPage;

  const QuranLineReader({super.key, this.startPage = 1});

  @override
  State<QuranLineReader> createState() => _QuranLineReaderState();
}

class _QuranLineReaderState extends State<QuranLineReader>
    with SingleTickerProviderStateMixin {
  late final Future<List<List<String>>> _pages;
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _speed = 0;
  double _pageExtent = 0;
  int _currentPage = 1;
  bool _initialJumpDone = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.startPage.clamp(1, 604).toInt();
    _scrollController = ScrollController()..addListener(_onScroll);
    _ticker = createTicker(_onTick);
    _pages = rootBundle.loadString('assets/data/quran_lines.json').then((text) {
      final decoded = jsonDecode(text);
      if (decoded is! List || decoded.length != 604) {
        throw const FormatException('Quran line source must have 604 pages.');
      }
      return decoded.map<List<String>>((page) {
        if (page is! List || page.isEmpty) {
          throw const FormatException('Invalid Quran line page.');
        }
        return page.map<String>((line) => line as String).toList();
      }).toList();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _pageExtent <= 0) return;
    final next = (_scrollController.offset / _pageExtent).round() + 1;
    final page = next.clamp(1, 604).toInt();
    if (page != _currentPage && mounted) {
      setState(() => _currentPage = page);
      app.prefs.setInt('mushaf_page', page);
    }
  }

  void _setSpeed(double value) {
    _speed = value.clamp(0, 1).toDouble();
    if (_speed == 0) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    if (!_scrollController.hasClients || _speed == 0) return;
    final seconds =
        (delta.inMicroseconds / Duration.microsecondsPerSecond).clamp(0.0, 0.05).toDouble();
    final pos = _scrollController.position;
    final next = (_scrollController.offset + seconds * 20 * _speed)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
    _scrollController.jumpTo(next);
    if (next >= pos.maxScrollExtent) _setSpeed(0);
  }

  void _goto(int requestedPage) {
    final page = requestedPage.clamp(1, 604).toInt();
    if (!_scrollController.hasClients || _pageExtent <= 0) return;
    _scrollController.animateTo(
      (page - 1) * _pageExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _askPage() async {
    var text = '';
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go to Quran page'),
        content: TextField(
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: '1 - 604'),
          onChanged: (value) => text = value,
          onSubmitted: (value) =>
              Navigator.pop(dialogContext, int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (result != null) _goto(result);
  }

  String _surahTitle() {
    final surah = surahAtPage(_currentPage);
    for (final item in app.items) {
      if (item.id == 'quran-' + surah.toString()) return item.title;
    }
    return 'Surah ' + surah.toString();
  }

  Widget _linePage(List<String> lines, double width, bool dark) {
    final height = width * 1.4142;
    final pageColor = dark ? Colors.black : Colors.white;
    final textColor = dark ? Colors.white : Colors.black;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: pageColor),
          Image.asset(
            'assets/images/quran_border.png',
            fit: BoxFit.fill,
          ),
          Positioned(
            left: width * 0.09,
            right: width * 0.09,
            top: height * 0.105,
            bottom: height * 0.09,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  for (final line in lines)
                    Expanded(
                      child: Center(
                        child: line.isEmpty
                            ? const SizedBox.shrink()
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'Amiri',
                                    fontWeight: FontWeight.w400,
                                    fontSize: width * 0.050,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<String>>>(
      future: _pages,
      builder: (context, snapshot) {
        // Preserve the working original Mushaf when line data isn't installed.
        if (snapshot.hasError) {
          return MushafScreen(startPage: widget.startPage);
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final pages = snapshot.data!;
        return ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final dark = app.dark;
            return Scaffold(
              backgroundColor: dark ? Colors.black : const Color(0xFFF2F2F2),
              appBar: AppBar(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_surahTitle() + ' • Juz ' + juzAtPage(_currentPage).toString(),
                        style: const TextStyle(fontFamily: 'Arial', fontSize: 17, letterSpacing: 0)),
                    Text('Page ' + _currentPage.toString() + ' / 604',
                        style: const TextStyle(fontFamily: 'Arial', fontSize: 12, letterSpacing: 0)),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.find_in_page_outlined),
                    tooltip: 'Go to page',
                    onPressed: _askPage,
                  ),
                  themeToggleAction(),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth - 48;
                  final maxHeightWidth = (constraints.maxHeight - 24) / 1.4142;
                  final width =
                      [maxWidth, maxHeightWidth, 530.0].reduce(
                        (a, b) => a < b ? a : b,
                      ).clamp(180.0, 530.0).toDouble();
                  _pageExtent = width * 1.4142 + 12;
                  if (!_initialJumpDone) {
                    _initialJumpDone = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _scrollController.hasClients) {
                        _scrollController.jumpTo(
                            (widget.startPage.clamp(1, 604) - 1) * _pageExtent);
                      }
                    });
                  }
                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        itemExtent: _pageExtent,
                        itemCount: pages.length,
                        itemBuilder: (context, index) => Center(
                          child: _linePage(pages[index], width, dark),
                        ),
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
                        left: 0,
                        child: Center(
                          child: IconButton(
                            onPressed: () => _goto(_currentPage + 1),
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Next page',
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 52,
                        child: Center(
                          child: IconButton(
                            onPressed: () => _goto(_currentPage - 1),
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Previous page',
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
      },
    );
  }
}
