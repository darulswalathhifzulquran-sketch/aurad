import 'package:flutter/material.dart';

/// Shared page-footer plaque used by every book reader.
/// The Arabic is rendered as vector font glyphs, not a blurry bitmap.
/// This is the small bottom badge only, not a page or border replacement.
class AcademyFooter extends StatelessWidget {
  final bool dark;
  const AcademyFooter({super.key, required this.dark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final fontSize = (h * 0.48).clamp(7.0, 25.0).toDouble();
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF050505) : Colors.white,
            border: Border.all(
              color: dark ? const Color(0xFFEBCB84) : Colors.black,
              width: (h * 0.055).clamp(1.0, 2.0).toDouble(),
            ),
            borderRadius: BorderRadius.circular(
              (h * 0.19).clamp(3.0, 10.0).toDouble(),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: h * .12),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'جامعة الإمام النووي ﷺ',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontFamilyFallback: const [
                    'ArabicFont',
                    'Noto Naskh Arabic',
                    'Traditional Arabic',
                  ],
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  height: 1.0,
                  color: dark ? Colors.white : Colors.black,
                  shadows: dark
                      ? null
                      : const [
                          Shadow(
                            color: Color(0x33000000),
                            offset: Offset(0, 1),
                            blurRadius: 1,
                          ),
                        ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
