import 'dart:convert';
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
  static final _jamiaHeaderMark = base64Decode('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');
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
                    // Cover the share glyph baked into the home artwork.
                    // The institution mark is embedded, so no additional
                    // asset download is needed for this header replacement.
                    Positioned(
                      left: 780 * scale,
                      top: mapY(18),
                      width: 132 * scale,
                      height: mapY(168) - mapY(18),
                      child: ColoredBox(
                        color: const Color(0xFF041A36),
                        child: Center(
                          child: Image.memory(
                            _jamiaHeaderMark,
                            width: 104 * scale,
                            height: 104 * scale,
                            fit: BoxFit.contain,
                            semanticLabel: 'Jamia Imam Navavi (RA)',
                          ),
                        ),
                      ),
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
