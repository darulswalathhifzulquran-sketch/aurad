import 'package:flutter/material.dart';

/// The EXACT user-provided academy artwork, shared by every non-Qur'an book.
/// The background around the plaque is transparent in the installed PNG.
/// Do not redraw the Arabic letters or add a second box around the artwork.
class AcademyFooter extends StatelessWidget {
  final bool dark;

  const AcademyFooter({super.key, required this.dark});

  static const String asset = 'assets/images/academy_footer_exact.png';

  static const ColorFilter _invertForDark = ColorFilter.matrix([
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final plaque = Image.asset(
      asset,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          const SizedBox.shrink(),
    );

    // One artwork, one outline (already present in the supplied image).
    // Do not wrap it in another bordered card/white rectangle.
    return dark
        ? ColorFiltered(colorFilter: _invertForDark, child: plaque)
        : plaque;
  }
}
