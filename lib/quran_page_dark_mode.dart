import 'dart:typed_data';

/// Converts one light Quran page (BGRA bytes) to the approved Dark Mode look:
/// black paper, white Arabic ink, original blue/pink ornaments.
///
/// Why this replaces the old version: the old code decided per pixel with hard
/// cut-offs (`chroma >= 26`). The pale-blue paper inside the Quran text area
/// (e.g. the Al-Fatiha circle) sits right on that cut-off, so neighbouring
/// pixels flipped at random and the letters turned into noise. Here every
/// decision is a smooth blend, so JPEG noise can only change a pixel slightly,
/// never flip it. Alpha is left untouched.
///
/// Measured on the supplied quran.pdf (pages are 750x1075 JPEGs):
///   paper  : saturation 0.06-0.21, brightness > 0.75   -> becomes black
///   ink    : brightness 0.14-0.33 (dark navy/black)     -> becomes white
///   ornament: saturation 0.66-0.99, brightness 0.56-0.91 -> kept as is
Uint8List darkenQuranPagePixels(
  Uint8List bgraPixels, {
  required int width,
  required int height,
}) {
  if (width <= 0 ||
      height <= 0 ||
      bgraPixels.lengthInBytes != width * height * 4) {
    throw ArgumentError.value(
      bgraPixels.lengthInBytes,
      'bgraPixels.lengthInBytes',
      'Must contain exactly width * height BGRA pixels.',
    );
  }

  const double inkLow = 30; // luminance that maps to full white ink
  const double paperHigh = 238; // luminance that maps to full black paper

  final out = Uint8List.fromList(bgraPixels);
  for (var i = 0; i < out.length; i += 4) {
    final blue = bgraPixels[i];
    final green = bgraPixels[i + 1];
    final red = bgraPixels[i + 2];

    final maxC = red > green ? (red > blue ? red : blue) : (green > blue ? green : blue);
    final minC = red < green ? (red < blue ? red : blue) : (green < blue ? green : blue);

    final value = maxC / 255.0;
    final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;

    // Weight of "this pixel is a coloured ornament". Dark ink can have a high
    // saturation too (navy), so brightness must also be high.
    final keep = _smoothstep(0.28, 0.50, saturation) * _smoothstep(0.38, 0.55, value);

    final luminance = 0.3 * red + 0.6 * green + 0.1 * blue;
    final ink = ((paperHigh - luminance) / (paperHigh - inkLow)).clamp(0.0, 1.0).toDouble() * 255.0;

    out[i] = _toByte(ink * (1 - keep) + blue * keep);
    out[i + 1] = _toByte(ink * (1 - keep) + green * keep);
    out[i + 2] = _toByte(ink * (1 - keep) + red * keep);
    // out[i + 3] (alpha) stays as in the source.
  }
  return out;
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0).toDouble();
  return t * t * (3 - 2 * t);
}

int _toByte(double v) => (v + 0.5).floor().clamp(0, 255).toInt();
