import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Quran-only decoded image cache. No HTML platform views, JPEG re-encoding
/// or image src swapping while a page is visible. Keep a small working set.
class QuranArtwork {
  final ui.Image image;
  final Rect source;
  const QuranArtwork(this.image, this.source);
}

class QuranArtworkCache {
  final _ready = LinkedHashMap<int, QuranArtwork>();
  final _pending = <int, Future<QuranArtwork>>{};
  int _center = 1;
  bool _closed = false;
  QuranArtwork? _lastVisible;

  // The last actually displayed bitmap is held independently of the bounded
  // decode cache. While the next leaf is loading we can paint this instead
  // of revealing an empty white/black frame.
  QuranArtwork? visibleFallback() {
    if (_closed || _lastVisible == null) return null;
    final image = _lastVisible!;
    return QuranArtwork(image.image.clone(), image.source);
  }

  void rememberVisible(QuranArtwork artwork) {
    if (_closed) return;
    final saved = QuranArtwork(artwork.image.clone(), artwork.source);
    final previous = _lastVisible;
    _lastVisible = saved;
    previous?.image.dispose();
  }

  QuranArtwork? lookup(int page) => _ready[page];

  void centerOn(int page) {
    _center = page;
    _trim();
  }

  Future<QuranArtwork> prepare(int page) {
    final ready = _ready[page];
    if (ready != null) return Future.value(ready);
    if (_closed) return Future.error(StateError('Reader closed'));
    return _pending.putIfAbsent(page, () async {
      try {
        final art = await _decode(page);
        if (_closed) {
          art.image.dispose();
          throw StateError('Reader closed');
        }
        _ready[page] = art;
        _trim(protect: page);
        return art;
      } finally {
        _pending.remove(page);
      }
    });
  }

  void _trim({int? protect}) {
    // Visible widgets own cloned handles, so cache eviction can't erase
    // a page which is still on screen.
    while (_ready.length > 9) {
      final candidates = _ready.keys
          .where((p) => p != _center && p != protect).toList()
        ..sort((a, b) => (b - _center).abs().compareTo((a - _center).abs()));
      if (candidates.isEmpty) break;
      final removed = _ready.remove(candidates.first)!;
      // A completed future may still be handing its image to a widget.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        removed.image.dispose();
      });
    }
  }

  Future<QuranArtwork> _decode(int page) async {
    final number = page.toString().padLeft(4, '0');
    final bytes = await rootBundle.load('assets/quran_pages/page_$number.jpg');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final ui.Image image;
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    Rect source = Rect.fromLTWH(
      0, 0, image.width.toDouble(), image.height.toDouble());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data != null) {
        final rgba = data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes);
        final w = image.width, h = image.height;
        int left = w, right = -1, top = h, bottom = -1;
        // Include ALL printed ink and colored decoration, not just the
        // green frame. This retains the original Surah/Juz/Hizb/page number.
        // Only nearly white paper can be omitted; leave a safety margin.
        // Sampling every fourth pixel reduces decode-time image scanning by
        // roughly 4x without changing the painted image resolution.
        for (int y = 0; y < h; y += 4) {
          for (int x = 0; x < w; x += 4) {
            final i = (y * w + x) * 4;
            final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
            if (r >= 230 && g >= 230 && b >= 230) continue;
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
        if (right - left >= w * 0.15 && bottom - top >= h * 0.15) {
          final pad = (w * 0.022).round().clamp(10, 60);
          source = Rect.fromLTRB(
            (left - pad).clamp(0, w).toDouble(),
            (top - pad).clamp(0, h).toDouble(),
            (right + pad + 2).clamp(0, w).toDouble(),
            (bottom + pad + 2).clamp(0, h).toDouble(),
          );
        }
      }
    } catch (_) {
      // If pixel readback is unavailable, show the complete source page.
    }
    return QuranArtwork(image, source);
  }

  void dispose() {
    _closed = true;
    for (final art in _ready.values) {
      art.image.dispose();
    }
    _ready.clear();
    _lastVisible?.image.dispose();
    _lastVisible = null;
  }
}

/// Render original pixels on Flutter's own canvas. The cached page is
/// available synchronously when navigating to a prepared adjacent page.
class CachedQuranPage extends StatefulWidget {
  final int page;
  final bool dark;
  final bool active;
  final QuranArtworkCache cache;
  const CachedQuranPage({
    super.key, required this.page, required this.dark,
    required this.cache, this.active = false,
  });

  @override
  State<CachedQuranPage> createState() => _CachedQuranPageState();
}

class _CachedQuranPageState extends State<CachedQuranPage> {
  QuranArtwork? _art;
  QuranArtwork? _fallback;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CachedQuranPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _art != null) {
      widget.cache.rememberVisible(_art!);
    }
  }

  void _load() {
    final ready = widget.cache.lookup(widget.page);
    if (ready != null) {
      _art = QuranArtwork(ready.image.clone(), ready.source);
      if (widget.active) widget.cache.rememberVisible(_art!);
      return;
    }
    _fallback = widget.cache.visibleFallback();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final art = await widget.cache.prepare(widget.page);
      if (!mounted || _art != null) return;
      final clone = QuranArtwork(art.image.clone(), art.source);
      if (widget.active) widget.cache.rememberVisible(clone);
      setState(() {
        _art = clone;
        _fallback?.image.dispose();
        _fallback = null;
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _art?.image.dispose();
    _fallback?.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A previously mounted off-screen cell may still be waiting on its
    // future when an arrow jump arrives. Render the cached bitmap now,
    // rather than showing a loading frame while that future settles.
    if (_art == null) {
      final ready = widget.cache.lookup(widget.page);
      if (ready != null) {
        _art = QuranArtwork(ready.image.clone(), ready.source);
        _fallback?.image.dispose();
        _fallback = null;
        if (widget.active) widget.cache.rememberVisible(_art!);
        _error = false;
      }
    }
    final art = _art ?? _fallback;
    final paper = widget.dark ? Colors.black : Colors.white;
    return ColoredBox(
      color: paper,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (art != null)
            RepaintBoundary(
              child: CustomPaint(painter: _ArtworkPainter(art, widget.dark)),
            ),
          if (_art == null)
            Center(
              child: _error
                  ? TextButton(
                      onPressed: () {
                        setState(() => _error = false);
                        _fetch();
                      },
                      child: const Text('Retry page'),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.dark
                            ? const Color(0xCC111E21)
                            : const Color(0xE6FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ArtworkPainter extends CustomPainter {
  final QuranArtwork art;
  final bool dark;
  const _ArtworkPainter(this.art, this.dark);

  // Mild contrast/saturation correction only; original artwork is untouched.
  // Dark mode reverses luminance while retaining the green ornament hue.
  static const _light = ColorFilter.matrix(<double>[
    // Pure white page, stronger readable black calligraphy and a clearer
    // mint ornament. No resaving/recompressing of the source Quran JPEG.
    1.24, -0.10, -0.08, 0, -12,
    -0.015, 1.13, -0.015, 0, -6,
    -0.075, -0.06, 1.13, 0, -8,
    0, 0, 0, 1, 0,
  ]);
  static const _dark = ColorFilter.matrix(<double>[
    0.574, -1.430, -0.144, 0, 255,
    -0.426, -0.430, -0.144, 0, 255,
    -0.426, -1.430, 0.856, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || art.source.isEmpty) return;
    final fit = applyBoxFit(BoxFit.contain, art.source.size, size);
    final dst = Alignment.center.inscribe(fit.destination, Offset.zero & size);
    canvas.drawImageRect(art.image, art.source, dst,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = dark ? _dark : _light);
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter old) =>
      old.art != art || old.dark != dark;
}
