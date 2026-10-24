import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';

const Color kLcd = Color(0xFFC9D2B3);
const Color kLcdOn = Color(0xFF1B1F14);
const Color kLcdOff = Color(0x181B1F14);

/// Draws digits like an LCD tally counter. Blank cells show faint "8"s.
class SevenSegPainter extends CustomPainter {
  final String digits;
  SevenSegPainter(this.digits);

  static const Map<String, String> segs = {
    '0': 'abcdef',
    '1': 'bc',
    '2': 'abdeg',
    '3': 'abcdg',
    '4': 'bcfg',
    '5': 'acdfg',
    '6': 'acdefg',
    '7': 'abc',
    '8': 'abcdefg',
    '9': 'abcdfg',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final n = digits.length;
    final cw = size.width / n;
    final gap = cw * 0.18;
    final w = cw - gap;
    final h = size.height;
    final t = w * 0.2;
    for (var i = 0; i < n; i++) {
      final x0 = i * cw + gap / 2;
      final lit = segs[digits[i]] ?? '';
      void seg(String name, Rect r) {
        final p = Paint()..color = lit.contains(name) ? kLcdOn : kLcdOff;
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(t / 2)), p);
      }

      seg('a', Rect.fromLTWH(x0 + t, 0, w - 2 * t, t));
      seg('g', Rect.fromLTWH(x0 + t, h / 2 - t / 2, w - 2 * t, t));
      seg('d', Rect.fromLTWH(x0 + t, h - t, w - 2 * t, t));
      seg('f', Rect.fromLTWH(x0, t, t, h / 2 - t * 1.25));
      seg('b', Rect.fromLTWH(x0 + w - t, t, t, h / 2 - t * 1.25));
      seg('e', Rect.fromLTWH(x0, h / 2 + t * 0.25, t, h / 2 - t * 1.25));
      seg('c', Rect.fromLTWH(x0 + w - t, h / 2 + t * 0.25, t, h / 2 - t * 1.25));
    }
  }

  @override
  bool shouldRepaint(covariant SevenSegPainter old) => old.digits != digits;
}

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  void _tap() {
    app.incCounter();
    HapticFeedback.lightImpact();
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset counter?'),
        content: const Text('The count will go back to 0.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) app.resetCounter();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final count = app.counter.toString();
        final n = count.length > 5 ? count.length : 5;
        final digits = count.padLeft(n, ' ');
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Expanded(child: Text('Counter')),
                const Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'العداد',
                    style: TextStyle(
                        fontFamily: kArabicFont,
                        fontFamilyFallback: kFontFallback,
                        fontSize: 26),
                  ),
                ),
              ],
            ),
          ),
          body: LayoutBuilder(
            builder: (context, box) {
              var w = box.maxWidth * 0.8;
              if (w > 340) w = 340;
              if (w > box.maxHeight * 0.62) w = box.maxHeight * 0.62;
              if (w < 220) w = 220;
              final plus = w * 0.42;
              final small = w * 0.17;
              return Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: w,
                    padding: EdgeInsets.all(w * 0.07),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6B2A1A),
                          Color(0xFF8E3B22),
                          Color(0xFF4B170D),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(w * 0.12),
                      boxShadow: const [
                        BoxShadow(
                            blurRadius: 14,
                            offset: Offset(0, 6),
                            color: Colors.black45),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LCD screen
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(w * 0.035),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15110F),
                            borderRadius: BorderRadius.circular(w * 0.05),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: w * 0.05, vertical: w * 0.05),
                            decoration: BoxDecoration(
                              color: kLcd,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: CustomPaint(
                                size: Size(n * 34.0, 64),
                                painter: SevenSegPainter(digits),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: w * 0.1),
                        // Reset (side) + big plus button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: const Color(0xFF2B0B06),
                                  elevation: 4,
                                  clipBehavior: Clip.antiAlias,
                                  shape: const CircleBorder(
                                      side: BorderSide(
                                          color: Color(0xFFB5894A), width: 2)),
                                  child: InkWell(
                                    onTap: app.counter == 0
                                        ? null
                                        : () => _confirmReset(context),
                                    child: SizedBox(
                                      width: small,
                                      height: small,
                                      child: Icon(
                                        Icons.refresh,
                                        size: small * 0.55,
                                        color: app.counter == 0
                                            ? Colors.white24
                                            : const Color(0xFFFFB4A8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'RESET',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      letterSpacing: 1),
                                ),
                              ],
                            ),
                            SizedBox(width: w * 0.1),
                            Material(
                              color: const Color(0xFF3A0F08),
                              elevation: 6,
                              clipBehavior: Clip.antiAlias,
                              shape: const CircleBorder(
                                  side: BorderSide(
                                      color: Color(0xFFD9A441), width: 3)),
                              child: InkWell(
                                onTap: _tap,
                                child: SizedBox(
                                  width: plus,
                                  height: plus,
                                  child: Icon(Icons.add,
                                      size: plus * 0.6,
                                      color: const Color(0xFFF5E1B0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: w * 0.02),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
