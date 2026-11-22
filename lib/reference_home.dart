import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static final _jamiaHeaderMark = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAHAAAABWCAMAAAAgy+JSAAAAkFBMVEWtk10IX2G7e2q9fT4JXWOAgoS3klu1kVsHXWMHXGL//wD/AAC4klv/f3/Zn10AOHx+gYQAPj6AgYWNjY+Bgob///9ialkA//9Pcmh+gYR/fxl7hoYAAP9sbJN/gYTCml9VqlXAmF/Oo2YAAAC7lFwHXWMIYGeEhoq4kVsAWFjAmF4Afn63klrCmmCqqlV/f39bnx8SAAAAMHRSTlMUHgUE1nnVapxeAQGPAgcE4wTQHKUBBQH4YgIgARKXYQOm/wD28/78rwf+Akz+AwNiAWw2AAAFjElEQVR42u2aa3ejOAyGHUhxwq25tEnvM7uChKv9///dSjJpk24Bkwmc/bA+nQYC1sMrS7LSjIArxhpgseCX4UNcMece8sXhsJjhwRTAEmB5OKTpIV3yydjANawXiKNxWKyHu3UoMIfZnOQ9PdHv+QzfGBOYN+6cr47H1bxxaz4ecA0zcudheXdcrY53Szpe5MPcKga7k/z4fMTx/HmajwPM2Z0kKb8j4F1O6cFuzccA5kDWD7hoOzBAPIBlSs8wgCiG6Gv8p09AffLyAI3Cfv1ICleXMyCeUhwd7NdRWNeX+eEwNzlwDqQ3FnSlvC2QBaaNjgsgXUoHSLQE3pOMRVOtL4GX124FZI8umxT/BlxTusxhf+M1xGCcNQv1DViiTw/zWwdNnnYD0/+B/3VgCX1A28wXdmlPhbQLSOXULvWFVdbzvtsJ5G3r/ibAfWnamB4g7yTl/s+BjTv7FeI/G7eKXnc2u3pf0JideNbb4Ig+d7Ih9FZvlPJOjLGz318PLGmvS/nBLfJwbe7tacdFJy9v2ph92Q8sy6bJmnUSO4BvJXvJNJ42laZpN+azt7ergKZNW5qPZValbc0R3d3EiZ42bQllaV9Ly9Ok/CqF6dnD2hZvdgveORzIz5rm+dDdIi/TTonCqm0aAOxrqVqBe9M2DVdoWqpr1vCsbfoBuGoBmpaqvCZKO4DPDzieO4D5TYGwJd7Dh4ZpgBq2m9UGf96NxNGBj7ClmDmu3vFwCuA7AldE3MJ2Ipd+HI8bRH5M41Lj0S39emWfjg3ccto/fPDfMbaTuPT9wbj0YTdVlOoNATevE0UpVZrjZnOcsNJoWOGAqSqNkbi6mxT4usEVnA6IyNVGA0wJpML2OB3wEV638HYLhdr9HDsCujtzomaXCi8bdL6ommkuAXdfdnQXMLhoMS7aPfq4pn5/nu52n4e/Y/q49nUnns1bjV4CAxC/qtOQT09P8usM9WInptQ3eYGKsFNDTbJl4i8BfhtQg0jq4seRJInnhRXdfY4MYjJRhZ6HN/w8s04E6BagAlEX9Y+DkMTNqnOkIlqW8PMULTPrWkDU5lI/kFnLQA1enSR14iFS8bI8RuBIry7oXdTfMvEv2e7S7k+u5DkyXRMyYnlV8wzoa2fwn6ADGr7juM6/huu4yiS5CAmZhA64LoiMcaExodUPM3GucH02/R2oex7MEXHsnpC1h9MqOkgkHvlOHIuox4D+rjB22oeIm6qgkMnCkkpSpJA6ftM4vcNEfKnwBR+8c3iZyYlYo3Vp3isSXExXk6lYhpnXbSGMX76AEeVD9/0Y9ElG/os0Zg8ZJ7+6PmWGxGDqn99kh1HoiyzpGTUzJIYLzpG4fBkdIlzSpaLum5/F/uUaiu5RyczkhIAYCxLyXiAKolNmZLLqMXDFl13oOtIhiZd4ItC+D2HBuodY8RUPt/v5HN5mBIVLLUPkCnB838k4MzAa8HqPQtdwfOtnUyqinECRJErS+kXEyygzIjcaULEshlkDFaAuLi8Z8lxApXUIHDqYGVaG0JLXG19NlFUvaNgJIEOFwsfkkMxTOtC8Z1gNDLq2HfD7flhQ0fYx7zLCuNoXRiniTKgmNnZwd6wyi+GZfSKkvEtYoAPoW08oX5+KuGdjKKssgyY2RTtTuHBFRp0Gg0H5Pi0KZYayDBqlHNU7qNSTENToJUUVuCiw4NAxocpblO63gyjbtIhwh6X8C42wxrMRh04hqYjf/FtuTEPemFAYbkjI8SCKuMpJiP0xvsfXkeDIluAo8qikbT8ksBuM8h8HgHXhEuKB8+VZPh8HqAOWKGiHwtfYvHquDyMBsS/xCq7b2NCgJwPaGItskMBhQPIp5iJmvUj+DgG7qqrmOj4WkDplSZ8VfDCfGQIt5SAcwD8gTNGFYdKfFQAAAABJRU5ErkJggg==');
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
                        child: _CleanHomeArtwork(fallback: _missingArtwork(scale)),
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
                                  child: _CleanHomeArtwork(fallback: _missingArtwork(scale)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    // User-supplied Riyadul Adkar white mark with its
                    // exact Arabic lettering; transparent PNG, no violet tile.
                    Positioned(
                      left: 38 * scale,
                      top: mapY(10),
                      width: 170 * scale,
                      height: mapY(178) - mapY(10),
                      child: Semantics(
                        button: true,
                        label: 'Riyadul Adkar — Open navigation',
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: onMenu,
                            borderRadius: BorderRadius.circular(14 * scale),
                            child: Image.asset(
                              'assets/images/riyadul_adkar_white_logo.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.menu_book, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Jamia header symbol only; Arabic and English names are
                    // retained on the About page in the original logo font.
                    Positioned(
                      left: 765 * scale,
                      top: mapY(16),
                      width: 151 * scale,
                      height: mapY(171) - mapY(16),
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/images/jamia_symbol_only.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
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
                    // Compact two-line university signature, matching the
                    // exact requested POWERED BY / JAMIA model. An equally
                    // sized About JAMIA button sits directly below it.
                    Positioned(
                      left: 28 * scale,
                      right: 28 * scale,
                      top: mapY(1339),
                      bottom: 9 * scale,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Flexible(
                            child: Container(
                              width: width * 0.84,
                              decoration: BoxDecoration(
                                color: const Color(0xFF082747),
                                borderRadius: BorderRadius.circular(15 * scale),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale, vertical: 7 * scale,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'P O W E R E D  B Y',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Color(0xFFE2EAF0),
                                        fontSize: 13,
                                        letterSpacing: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'JAMIA IMAM NAVAVI (RA)',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 21,
                                        color: Color(0xFFE8C784),
                                        fontWeight: FontWeight.w800,
                                        shadows: [
                                          Shadow(color: Color(0xFF19110B),
                                            blurRadius: 1.5,
                                            offset: Offset(0.5, 1)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 11 * scale),
                          SizedBox(
                            width: width * 0.92,
                            height: (62 * scale).clamp(33.0, 49.0).toDouble(),
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const _AboutJamiaScreen(),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF3F0E7),
                                backgroundColor: const Color(0xAA061F3A),
                                side: const BorderSide(
                                  color: Color(0xFFAD8958), width: 0.8,
                                ),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text.rich(
                                    TextSpan(children: [
                                      TextSpan(text: 'About ',
                                        style: TextStyle(
                                          color: Color(0xFFE6E8EB),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 17,
                                        )),
                                      TextSpan(text: 'JAMIA',
                                        style: TextStyle(
                                          color: Color(0xFFE5C17B),
                                          fontFamily: 'Georgia',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                        )),
                                    ]),
                                  ),
                                  SizedBox(height: 6),
                                  SizedBox(
                                    width: 85, height: 1,
                                    child: ColoredBox(
                                      color: Color(0xFFD3B170),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

// Clean the old, baked-in icons from the actual artwork, once per app
// session. Reconstruct the navy pixels using the original image at each
// edge of the erased region. No colored rectangular widgets are drawn.
class _CleanHomeArtwork extends StatelessWidget {
  final Widget fallback;
  const _CleanHomeArtwork({required this.fallback});
  static Future<ui.Image>? _cached;

  static Future<ui.Image> _prepare() async {
    final data = await rootBundle.load(ReferenceHome.imagePath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final original = (await codec.getNextFrame()).image;
    codec.dispose();
    final pixels = await original.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (pixels == null) return original;
    final w = original.width;
    final h = original.height;
    final rgba = Uint8List.fromList(pixels.buffer.asUint8List(
      pixels.offsetInBytes, pixels.lengthInBytes,
    ));
    // Only the menu and former share symbol are erased. The Arabic
    // title, three-dot menu, arch, and twelve tiles remain untouched.
    for (final range in const [[18.0, 218.0], [758.0, 920.0]]) {
      final left = (range[0] * w / 1024).round().clamp(1, w - 2).toInt();
      final right = (range[1] * w / 1024).round().clamp(left + 1, w - 1).toInt();
      final yStart = (4 * h / 1536).round();
      final yEnd = (178 * h / 1536).round().clamp(yStart + 1, h).toInt();
      final fade = (8 * h / 1536).clamp(1.0, double.infinity).toDouble();
      for (var y = yStart; y < yEnd; y++) {
        final blend = ((y - yStart) / fade)
            .clamp(0.0, 1.0).toDouble() *
            ((yEnd - 1 - y) / fade).clamp(0.0, 1.0).toDouble();
        final lo = (y * w + left - 1) * 4;
        final hi = (y * w + right) * 4;
        for (var x = left; x < right; x++) {
          final t = (x - left + 1) / (right - left + 1);
          final ix = (y * w + x) * 4;
          for (var channel = 0; channel < 3; channel++) {
            final color = rgba[lo + channel] * (1 - t) +
                rgba[hi + channel] * t;
            rgba[ix + channel] = (rgba[ix + channel] * (1 - blend) +
                color * blend).round().clamp(0, 255).toInt();
          }
        }
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba, w, h, ui.PixelFormat.rgba8888, completer.complete,
    );
    final cleaned = await completer.future;
    original.dispose();
    return cleaned;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: _cached ??= _prepare(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return fallback;
      final image = snapshot.data;
      if (image == null) return const ColoredBox(color: Color(0xFF041A36));
      return RawImage(image: image, fit: BoxFit.fill,
        filterQuality: FilterQuality.high);
    },
  );
}

// Preserve the teal, gray and gold Jamia emblem, removing only the
// dark blue pixels from the embedded mark itself, if any survived.
class _TransparentJamiaMark extends StatelessWidget {
  final Uint8List bytes;
  final double width;
  final double height;
  const _TransparentJamiaMark({
    required this.bytes, required this.width, required this.height,
  });
  static Future<ui.Image>? _cached;

  Future<ui.Image> _prepare() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final original = (await codec.getNextFrame()).image;
    codec.dispose();
    final data = await original.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return original;
    final rgba = Uint8List.fromList(data.buffer.asUint8List(
      data.offsetInBytes, data.lengthInBytes,
    ));
    for (var i = 0; i < rgba.length; i += 4) {
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      if (b > g + 4 && r < 35 && g < 80) {
        rgba[i] = 0;
        rgba[i + 1] = 0;
        rgba[i + 2] = 0;
        rgba[i + 3] = 0;
      } else {
        final alpha = rgba[i + 3] / 255;
        rgba[i] = (r * alpha).round();
        rgba[i + 1] = (g * alpha).round();
        rgba[i + 2] = (b * alpha).round();
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, original.width, original.height,
      ui.PixelFormat.rgba8888, completer.complete);
    final clean = await completer.future;
    original.dispose();
    return clean;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Jamia Imam Navavi (RA)',
    child: SizedBox(
      width: width, height: height,
      child: FutureBuilder<ui.Image>(
        future: _cached ??= _prepare(),
        builder: (context, snapshot) => snapshot.data == null
            ? Image.memory(bytes, fit: BoxFit.contain)
            : RawImage(image: snapshot.data, fit: BoxFit.contain,
                filterQuality: FilterQuality.high),
      ),
    ),
  );
}


/// Institution details, matching the supplied Jamia website footer.
/// A separate scrollable screen preserves the existing home navigation.
class _AboutJamiaScreen extends StatelessWidget {
  const _AboutJamiaScreen();

  static const _gold = Color(0xFFEBCB84);
  static const _ink = Color(0xFFE5EDF2);

  Future<void> _openWebsite(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://jamiaimamnavavi-ra.com/'),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (opened) return;
    } catch (_) {
      // Leave an accessible failure message rather than a silent tap.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Unable to open website. Visit jamiaimamnavavi-ra.com',
        )),
      );
    }
  }

  Widget _heading(String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
        color: _gold, fontSize: 19, fontWeight: FontWeight.w700,
      )),
      const SizedBox(height: 12),
      const SizedBox(width: 42, height: 2, child: ColoredBox(color: _gold)),
      const SizedBox(height: 14),
    ],
  );

  // Open native phone or email handlers. Calls are never initiated
  // automatically; the user confirms in their dialer.
  Future<void> _openContact(
    BuildContext context,
    Uri uri,
    String fallback,
  ) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return;
    } catch (_) {
      // Some desktop browsers have no handler for tel: or mailto:.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open $fallback on this device')),
      );
    }
  }

  Widget _linkedContact(
    BuildContext context, {
    required String label,
    required Uri uri,
    required String tooltip,
  }) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: () => _openContact(context, uri, label),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            height: 1.5,
            decoration: TextDecoration.underline,
            decorationColor: _gold,
          ),
        ),
      ),
    ),
  );

  Widget _contactRow(IconData icon, Widget content) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _gold),
        const SizedBox(width: 10),
        Expanded(child: content),
      ],
    ),
  );

  Widget _about(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('About Us'),
      const Text('JAMIA IMAM NAVAVI (RA)', style: TextStyle(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
      )),
      const SizedBox(height: 12),
      const Text(
        'Advanced Study and Research Centre and Public Charitable Trust',
        style: TextStyle(color: Color(0xFFBFCBD3), fontSize: 15, height: 1.5),
      ),
      const SizedBox(height: 12),
      const Text(
        'Bridging traditional Islamic knowledge and modern technology, with a commitment to faith, education and innovation.',
        style: TextStyle(color: _ink, fontSize: 15, height: 1.5),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => _openWebsite(context),
        style: TextButton.styleFrom(
          foregroundColor: _gold,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        icon: const Icon(Icons.language, size: 18),
        label: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Official Website', style: TextStyle(
              decoration: TextDecoration.underline,
            )),
            SizedBox(width: 6),
            Icon(Icons.open_in_new, size: 15),
          ],
        ),
      ),
    ],
  );

  Widget _contacts(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Stay in Touch'),
      _contactRow(
        Icons.phone_outlined,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linkedContact(
              context,
              label: '+91 88918 38472',
              uri: Uri(scheme: 'tel', path: '+918891838472'),
              tooltip: 'Call +91 88918 38472',
            ),
            _linkedContact(
              context,
              label: '+91 94943 13786',
              uri: Uri(scheme: 'tel', path: '+919494313786'),
              tooltip: 'Call +91 94943 13786',
            ),
            _linkedContact(
              context,
              label: '+91 62351 39072',
              uri: Uri(scheme: 'tel', path: '+916235139072'),
              tooltip: 'Call +91 62351 39072',
            ),
          ],
        ),
      ),
      _contactRow(
        Icons.mail_outline,
        _linkedContact(
          context,
          label: 'info@jamiaimamnavavi-ra.com',
          uri: Uri(
            scheme: 'mailto',
            path: 'info@jamiaimamnavavi-ra.com',
          ),
          tooltip: 'Compose email to Jamia Imam Navavi (RA)',
        ),
      ),
      _contactRow(
        Icons.location_on_outlined,
        const SelectableText(
          'Venmenad, Pavaratty\nThrissur, Kerala – 680507\nIndia',
          style: TextStyle(color: _ink, fontSize: 14, height: 1.65),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF071A2C),
    appBar: AppBar(
      backgroundColor: const Color(0xFF061C36),
      foregroundColor: _gold,
      title: const Text('About Jamia'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1B25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33EBCB84)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Exact user-provided Jamia institutional lockup.
                    // Name lettering is preserved as source-image pixels,
                    // recolored ivory solely for contrast on this dark card.
                    Center(
                      child: Image.asset(
                        'assets/images/jamia_full_lockup_ivory.png',
                        width: MediaQuery.sizeOf(context).width < 600
                            ? 260 : 320,
                        height: MediaQuery.sizeOf(context).width < 600
                            ? 260 : 320,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0x33EBCB84)),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth >= 640
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _about(context)),
                          const SizedBox(width: 32),
                          Expanded(child: _contacts(context)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _about(context),
                          const SizedBox(height: 26),
                          _contacts(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
