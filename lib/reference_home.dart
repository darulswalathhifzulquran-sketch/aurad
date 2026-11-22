import 'package:flutter/material.dart';

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
    _HomeEntry('quran', 'Quran'),
    _HomeEntry('dikr', 'Dikr'),
    _HomeEntry('swalath', 'Swalath'),
    _HomeEntry('dua', 'Dua'),
    _HomeEntry('mawlid', 'Moulid'),
    _HomeEntry('mala', 'Malappatt'),
    _HomeEntry('baith', 'Baith'),
    _HomeEntry('ratib', 'Raatheeb'),
    _HomeEntry('majlisunnoor', 'Majlisunoor'),
    _HomeEntry('other', 'Other'),
    _HomeEntry('search', 'Search'),
    _HomeEntry('counter', 'Counter'),
  ];

  Widget _missingArtwork(double scale) {
    return ColoredBox(
      color: const Color(0xFF041A36),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24 * scale),
          child: Text(
            'The approved Home artwork could not be loaded.\n'
            'Check assets/images/aurad_reference_home.png.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFFF4DB),
              fontSize: 18 * scale,
            ),
          ),
        ),
      ),
    );
  }

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
    required double Function(double) mapY,
    required String label,
    required VoidCallback action,
  }) {
    return Positioned(
      left: x * scale,
      top: mapY(y),
      width: w * scale,
      height: mapY(y + h) - mapY(y),
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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF041A36),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobilePortrait = constraints.maxHeight.isFinite &&
                constraints.maxWidth > 0 && constraints.maxHeight > 0 &&
                constraints.maxWidth <= 620 &&
                constraints.maxHeight >= constraints.maxWidth;
            var width =
                constraints.maxWidth > 620 ? 620.0 : constraints.maxWidth;
            if (!mobilePortrait && constraints.maxHeight.isFinite) {
              final widthForHeight =
                  constraints.maxHeight * originalWidth / originalHeight;
              if (width > widthForHeight) width = widthForHeight;
            }
            final scale = width / originalWidth;
            final naturalHeight = originalHeight * scale;
            final height = mobilePortrait ? constraints.maxHeight : naturalHeight;

            // Keep the baked-in header and all 12 tiles proportional on tall
            // phones. Expand only the decorative areas above and below the
            // tile grid, so no blank outer bars or stretched icons appear.
            const cuts = <double>[0, 180, 508, 1330, originalHeight];
            final extra = height - naturalHeight;
            final segmented = mobilePortrait && extra > 0;
            final mapped = <double>[
              0,
              180 * scale,
              508 * scale + (segmented ? extra * 0.52 : 0.0),
              1330 * scale + (segmented ? extra * 0.52 : 0.0),
              height,
            ];
            double mapY(double y) {
              if (!segmented) return y * height / originalHeight;
              for (var k = 0; k < cuts.length - 1; k++) {
                if (y <= cuts[k + 1]) {
                  final t = (y - cuts[k]) / (cuts[k + 1] - cuts[k]);
                  return mapped[k] + t * (mapped[k + 1] - mapped[k]);
                }
              }
              return height;
            }

            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (!segmented)
                      Positioned.fill(
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => _missingArtwork(scale),
                        ),
                      )
                    else
                      for (var k = 0; k < cuts.length - 1; k++)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: mapped[k],
                          height: mapped[k + 1] - mapped[k],
                          child: ClipRect(
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: -cuts[k] *
                                      (mapped[k + 1] - mapped[k]) /
                                      (cuts[k + 1] - cuts[k]),
                                  width: width,
                                  height: originalHeight *
                                      (mapped[k + 1] - mapped[k]) /
                                      (cuts[k + 1] - cuts[k]),
                                  child: Image.asset(
                                    imagePath,
                                    fit: BoxFit.fill,
                                    filterQuality: FilterQuality.high,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) =>
                                        _missingArtwork(scale),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    // Institution branding in the decorative arch, below
                    // the title and above the first row of folder buttons.
                    // Keep the supplied composition, including both names,
                    // proportional and entirely visible on every screen.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: mapY(180),
                      height: mapY(508) - mapY(180),
                      child: IgnorePointer(
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0, 0.07, 0.93, 1],
                            ).createShader(rect),
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              'assets/images/jamia_home_arch.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The home illustration already includes a bright
                    // turquoise menu icon. Completely cover that old artwork
                    // BEFORE drawing the replacement circular Jamia logo.
                    // Otherwise a cyan/blue square remains behind the logo.
                    Positioned(
                      left: 40 * scale,
                      top: mapY(18),
                      width: 160 * scale,
                      height: mapY(173) - mapY(18),
                      child: const ColoredBox(
                        color: Color(0xFF041A36),
                      ),
                    ),
                    Positioned(
                      left: 56 * scale,
                      top: mapY(30),
                      width: 126 * scale,
                      height: mapY(156) - mapY(30),
                      child: Semantics(
                        button: true,
                        label: 'Jamia Imam Navavi — Open navigation',
                        child: Material(
                          color: const Color(0xFF041A36),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onMenu,
                            customBorder: const CircleBorder(),
                            // Supplied logo file includes an empty lower band.
                            // Top-aligned BoxFit.cover shows the full circular
                            // emblem, not the empty band below it.
                            child: Image.asset(
                              'assets/images/jamia_navavi_logo.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.menu_book, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _spot(
                      x: 786,
                      y: 28,
                      w: 112,
                      h: 124,
                      scale: scale,
                      mapY: mapY,
                      label: 'Share',
                      action: onShare,
                    ),
                    _spot(
                      x: 921,
                      y: 26,
                      w: 92,
                      h: 126,
                      scale: scale,
                      mapY: mapY,
                      label: 'More options',
                      action: onMenu,
                    ),
                    for (var i = 0; i < entries.length; i++)
                      _spot(
                        x: 49 + (i % 4) * 238,
                        y: 508 + (i ~/ 4) * 279,
                        w: 223,
                        h: 263,
                        scale: scale,
                      mapY: mapY,
                        label: 'Open ${entries[i].label}',
                        action: () => _open(entries[i].id),
                      ),
                  ],
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

  const _HomeEntry(this.id, this.label);
}
