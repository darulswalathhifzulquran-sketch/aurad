import 'package:flutter/material.dart';

/// Renders only the original academy artwork, with a single, neat outline.
/// No Arabic text is retyped and the interior is kept inside the border.
class AcademyFooter extends StatelessWidget {
  final bool dark;
  const AcademyFooter({super.key, required this.dark});

  static const asset = 'assets/images/academy_footer_exact.png';
  static const darkFilter = ColorFilter.matrix([
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final background = dark ? Colors.black : Colors.white;
    final stroke = dark ? Colors.white : Colors.black;
    final artwork = Image.asset(
      asset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, trace) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'جامعة الإمام النووي رضي الله عنه',
          maxLines: 1,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: stroke,
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: stroke, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: dark
              ? ColorFiltered(colorFilter: darkFilter, child: artwork)
              : artwork,
        ),
      ),
    );
  }
}
