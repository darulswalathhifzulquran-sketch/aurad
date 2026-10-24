import 'package:flutter/material.dart';

/// Pixel-aligned interactive edition of the supplied AL AURADU reference.
/// All visible artwork is taken from the approved image asset when supplied.
/// Flutter hotspots provide real navigation, not a non-interactive screenshot.
class ReferenceHome extends StatelessWidget {
  final ValueChanged<String> onFolder;
  final VoidCallback onMenu;
  final VoidCallback onShare;
  final VoidCallback onSearch;
  final VoidCallback onOther;
  const ReferenceHome({
    super.key,
    required this.onFolder,
    required this.onMenu,
    required this.onShare,
    required this.onSearch,
    required this.onOther,
  });

  static const imagePath = 'assets/images/aurad_reference_home.png';
  static const originalWidth = 1024.0;
  static const originalHeight = 1536.0;

  static const entries = <_HomeEntry>[
    _HomeEntry('quran', 'Quran', Icons.menu_book),
    _HomeEntry('dikr', 'Dikr', Icons.grain),
    _HomeEntry('swalath', 'Swalath', Icons.mosque),
    _HomeEntry('dua', 'Dua', Icons.back_hand),
    _HomeEntry('mawlid', 'Moulid', Icons.auto_stories),
    _HomeEntry('mala', 'Malappatt', Icons.nightlight),
    _HomeEntry('baith', 'Baith', Icons.menu_book_outlined),
    _HomeEntry('ratib', 'Raatheeb', Icons.filter_vintage),
    _HomeEntry('majlisunnoor', 'Majlisunoor', Icons.light),
    _HomeEntry('other', 'Other', Icons.window),
    _HomeEntry('search', 'Search', Icons.search),
    _HomeEntry('counter', 'Counter', Icons.numbers),
  ];

  void _open(String id) {
    if (id == 'search') {
      onSearch();
    } else if (id == 'other') {
      onOther();
    } else {
      onFolder(id);
    }
  }

  Widget _spot({
    required double x,
    required double y,
    required double w,
    required double h,
    required double scale,
    required String label,
    required VoidCallback action,
  }) {
    return Positioned(
      left: x * scale,
      top: y * scale,
      width: w * scale,
      height: h * scale,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(20 * scale),
            splashColor: const Color(0x88E6C276),
            highlightColor: const Color(0x44E6C276),
          ),
        ),
      ),
    );
  }

  Widget _illustrationFallback(BuildContext context) {
    const navy = Color(0xFF041C3A);
    const gold = Color(0xFFEBCB84);
    const lightGold = Color(0xFFFFE7AA);
    final screenW = MediaQuery.sizeOf(context).width;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0xFF174970), Color(0xFF05254B), navy],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MosqueBackdrop())),
          Align(
            alignment: const Alignment(0, -0.96),
            child: Text(
              'رياض الأذكار',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'ArabicFont',
                fontSize: screenW < 500 ? 28 : 38,
                color: const Color(0xFFFFF5DA),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.39),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: entries.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.76,
                ),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return Column(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF215078), Color(0xFF062548)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: lightGold, width: 1.8),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xAA00091C),
                                blurRadius: 8,
                                offset: Offset(2, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              e.icon,
                              color: i.isEven ? gold : const Color(0xFF87C8A8),
                              size: 35,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          e.label,
                          maxLines: 1,
                          style: const TextStyle(
                            color: lightGold,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF041A36),
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) {
            // A 2:3 design canvas maintains the exact submitted composition.
            // On short screens, it scrolls rather than clipping card controls.
            final width = c.maxWidth > 620 ? 620.0 : c.maxWidth;
            final height = width * originalHeight / originalWidth;
            final scale = width / originalWidth;
            return SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.fill,
                          // The fallback keeps the screen usable while the
                          // exact screenshot asset is being synced to GitHub.
                          errorBuilder: (_, __, ___) =>
                              _illustrationFallback(context),
                        ),
                      ),
                      _spot(
                        x: 55, y: 32, w: 120, h: 126,
                        scale: scale, label: 'Open navigation',
                        action: onMenu,
                      ),
                      _spot(
                        x: 786, y: 28, w: 112, h: 124,
                        scale: scale, label: 'Share',
                        action: onShare,
                      ),
                      _spot(
                        x: 921, y: 26, w: 92, h: 126,
                        scale: scale, label: 'More options',
                        action: onMenu,
                      ),
                      for (var i = 0; i < entries.length; i++)
                        _spot(
                          x: 49 + (i % 4) * 238,
                          y: 508 + (i ~/ 4) * 279,
                          w: 223,
                          h: 263,
                          scale: scale,
                          label: 'Open ${entries[i].label}',
                          action: () => _open(entries[i].id),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeEntry {
  final String id;
  final String label;
  final IconData icon;
  const _HomeEntry(this.id, this.label, this.icon);
}

/// Native-Dart fallback decoration, never used when the approved asset loads.
class _MosqueBackdrop extends CustomPainter {
  const _MosqueBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gold = Paint()
      ..color = const Color(0xFFAE8B54)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arch = Path()
      ..moveTo(w * .10, h * .36)
      ..lineTo(w * .10, h * .20)
      ..quadraticBezierTo(w * .18, h * .15, w * .28, h * .15)
      ..quadraticBezierTo(w * .40, h * .14, w * .50, h * .10)
      ..quadraticBezierTo(w * .60, h * .14, w * .72, h * .15)
      ..quadraticBezierTo(w * .82, h * .15, w * .90, h * .20)
      ..lineTo(w * .90, h * .36);
    canvas.drawPath(arch, gold);
    final building = Paint()..color = const Color(0xFF0B284C);
    canvas.drawRect(
        Rect.fromLTWH(w * .20, h * .26, w * .60, h * .10), building);
    canvas.drawOval(
        Rect.fromLTWH(w * .38, h * .19, w * .24, h * .15), building);
    for (final x in [0.25, 0.33, 0.68, 0.76]) {
      canvas.drawRect(Rect.fromLTWH(w * x, h * .18, w * .04, h * .18),
          building);
      canvas.drawOval(
          Rect.fromLTWH(w * (x - .005), h * .16, w * .05, h * .05),
          building);
    }
    final star = Paint()..color = const Color(0x88F5DDA0);
    for (var i = 0; i < 26; i++) {
      final x = ((i * 127) % 89 + 5) / 100;
      final y = ((i * 43) % 25 + 10) / 100;
      canvas.drawCircle(Offset(w * x, h * y), i % 5 == 0 ? 1.5 : .65, star);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
