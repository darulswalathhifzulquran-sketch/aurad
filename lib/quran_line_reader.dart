import 'package:flutter/material.dart';

import 'mushaf.dart';

/// The original, verified 604-page Mushaf is the only source of page artwork
/// and line boundaries. Do not reflow Quran text into widgets: doing so
/// changes ayah line starts, endings, glyph shaping, and verse ornaments.
///
/// The PDF viewer retains native zoom, scrolling, page-jump, navigation,
/// and the existing light/dark PDF variants.
class QuranLineReader extends StatelessWidget {
  final int startPage;

  const QuranLineReader({super.key, this.startPage = 1});

  @override
  Widget build(BuildContext context) {
    return MushafScreen(startPage: startPage.clamp(1, 604).toInt());
  }
}
