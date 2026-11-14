import 'package:flutter/material.dart';

/// Shared book-page footer. The reference art is always preferred and retains
/// the EXACT original Arabic lettering including the رضي الله عنه emblem.
/// No rasterization of Quran / book body content is involved.
class AcademyFooter extends StatelessWidget {
  final bool dark;
  const AcademyFooter({super.key, required this.dark});

  static const asset = 'assets/images/academy_footer_exact.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF070707) : Colors.white,
          border: Border.all(
            color: dark ? const Color(0xFFEBCB84) : Colors.black,
            width: 1.25,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'جامعة الإمام النووي رضي الله عنه',
            maxLines: 1,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontSize: 19,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
