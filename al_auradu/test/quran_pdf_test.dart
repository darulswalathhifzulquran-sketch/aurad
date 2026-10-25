import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:al_auradu/mushaf.dart';
import 'package:al_auradu/quran_pdf.dart';

void main() {
  test('Surah and Juz index retains 604-page Madinah mapping', () {
    expect(kSurahPage, hasLength(114));
    expect(kJuzPage, hasLength(30));
    expect(kSurahPage.first, 1);
    expect(kSurahPage.last, 604);
    expect(kJuzPage.first, 1);
    expect(kJuzPage.last, 582);
    expect(quranStartPageForId('quran-1'), 1);
    expect(quranStartPageForId('quran-2'), 2);
    expect(quranStartPageForId('quran-6'), 128);
    expect(quranStartPageForId('quran-114'), 604);
    expect(quranStartPageForId('juz-1'), 1);
    expect(quranStartPageForId('juz-30'), 582);
    for (final page in [...kSurahPage, ...kJuzPage]) {
      expect(page, inInclusiveRange(1, 604));
    }
  });

  test('Git LFS has materialized a real PDF, not its small pointer file',
      () async {
    final file = File('quran.pdf');
    expect(await file.exists(), true);
    // The Git pointer is only ~134 bytes; the source file is ~157 MB.
    expect(await file.length(), greaterThan(1000000));
    final header = await file.openRead(0, 5).first;
    expect(String.fromCharCodes(header), '%PDF-');
  });
}
