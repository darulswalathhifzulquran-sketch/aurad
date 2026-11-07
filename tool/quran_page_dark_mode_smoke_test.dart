import 'dart:typed_data';

import '../lib/quran_page_dark_mode.dart';

void main() {
  final original = Uint8List.fromList([
    250,
    250,
    250,
    255,
    10,
    10,
    10,
    255,
    220,
    100,
    30,
    255,
    30,
    170,
    230,
    255,
  ]);
  final dark = darkenQuranPagePixels(original, width: 4, height: 1);
  if (dark[0] != 0 ||
      dark[1] != 0 ||
      dark[2] != 0 ||
      dark[4] < 240 ||
      dark[8] != original[8] ||
      dark[9] != original[9] ||
      dark[10] != original[10] ||
      dark[12] != original[12] ||
      dark[13] != original[13] ||
      dark[14] != original[14] ||
      original[0] != 250) {
    throw StateError('Quran dark-mode pixel transformation failed.');
  }
  print('Quran dark-mode pixel smoke test passed.');
}
