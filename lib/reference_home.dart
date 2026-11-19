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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF041A36),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            var width =
                constraints.maxWidth > 620 ? 620.0 : constraints.maxWidth;
            if (constraints.maxHeight.isFinite) {
              final widthForHeight =
                  constraints.maxHeight * originalWidth / originalHeight;
              if (width > widthForHeight) width = widthForHeight;
            }
            final height = width * originalHeight / originalWidth;
            final scale = width / originalWidth;

            return Center(
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
                        errorBuilder: (_, __, ___) => _missingArtwork(scale),
                      ),
                    ),
                    // The home illustration already includes a bright
                    // turquoise menu icon. Completely cover that old artwork
                    // BEFORE drawing the replacement circular Jamia logo.
                    // Otherwise a cyan/blue square remains behind the logo.
                    Positioned(
                      left: 40 * scale,
                      top: 18 * scale,
                      width: 160 * scale,
                      height: 155 * scale,
                      child: const ColoredBox(
                        color: Color(0xFF041A36),
                      ),
                    ),
                    Positioned(
                      left: 56 * scale,
                      top: 30 * scale,
                      width: 126 * scale,
                      height: 126 * scale,
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
                      label: 'Share',
                      action: onShare,
                    ),
                    _spot(
                      x: 921,
                      y: 26,
                      w: 92,
                      h: 126,
                      scale: scale,
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
