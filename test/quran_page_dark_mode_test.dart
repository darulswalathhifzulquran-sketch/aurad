import 'dart:typed_data';

import 'package:al_auradu/quran_page_dark_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('darkens paper across the full page and preserves colored ornaments',
      () {
    const width = 100;
    const height = 120;
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = 255;
      pixels[i + 1] = 255;
      pixels[i + 2] = 255;
      pixels[i + 3] = 255;
    }

    void setPixel(int x, int y, int blue, int green, int red) {
      final offset = (y * width + x) * 4;
      pixels[offset] = blue;
      pixels[offset + 1] = green;
      pixels[offset + 2] = red;
    }

    for (var y = 8; y <= 111; y++) {
      setPixel(15, y, 200, 150, 20);
      setPixel(84, y, 200, 150, 20);
    }
    for (var x = 15; x <= 84; x++) {
      setPixel(x, 8, 200, 150, 20);
      setPixel(x, 111, 200, 150, 20);
    }
    for (var y = 40; y < 55; y++) {
      for (var x = 5; x < 11; x++) {
        setPixel(x, y, 190, 130, 25);
      }
    }
    setPixel(50, 50, 10, 10, 10);
    setPixel(49, 50, 244, 239, 228);
    setPixel(7, 45, 255, 255, 255);
    final sourcePixels = Uint8List.fromList(pixels);

    final dark = darkenQuranPagePixels(
      pixels,
      width: width,
      height: height,
    );
    int channel(int x, int y, int c) => dark[(y * width + x) * 4 + c];

    expect([channel(0, 0, 0), channel(0, 0, 1), channel(0, 0, 2)], [0, 0, 0]);
    expect([channel(49, 50, 0), channel(49, 50, 1), channel(49, 50, 2)],
        [0, 0, 0]);
    expect([channel(50, 50, 0), channel(50, 50, 1), channel(50, 50, 2)],
        [255, 255, 255]);
    expect([channel(15, 20, 0), channel(15, 20, 1), channel(15, 20, 2)],
        [200, 150, 20]);
    expect(
        [channel(7, 45, 0), channel(7, 45, 1), channel(7, 45, 2)], [0, 0, 0]);
    expect(pixels, sourcePixels);
  });

  test('rejects invalid pixel dimensions without modifying the source', () {
    final pixels = Uint8List.fromList([0, 0, 0, 255]);
    expect(
      () => darkenQuranPagePixels(pixels, width: 2, height: 2),
      throwsArgumentError,
    );
    expect(pixels, [0, 0, 0, 255]);
  });
}
