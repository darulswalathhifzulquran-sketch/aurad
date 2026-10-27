import 'package:flutter_test/flutter_test.dart';
import 'package:al_auradu/quran_vector_reader.dart';

void main() {
  test('Al Auradu maps 114 Surahs to standard 604-page Hafs starts', () {
    expect(quranStartPageForId('quran-1'), 1);
    expect(quranStartPageForId('quran-2'), 2);
    expect(quranStartPageForId('quran-6'), 128);
    expect(quranStartPageForId('quran-114'), 604);
    final starts = List<int>.generate(
        114, (index) => quranStartPageForId('quran-${index + 1}')!);
    expect(starts, hasLength(114));
    expect(starts, orderedEquals([...starts]..sort()));
    expect(starts.every((page) => page >= 1 && page <= 604), true);
  });

  test('30 Juz shortcuts map to standard 604-page Hafs starts', () {
    expect(quranStartPageForId('juz-1'), 1);
    expect(quranStartPageForId('juz-2'), 22);
    expect(quranStartPageForId('juz-30'), 582);
    final starts = List<int>.generate(
        30, (index) => quranStartPageForId('juz-${index + 1}')!);
    expect(starts, hasLength(30));
    expect(starts, orderedEquals([...starts]..sort()));
  });

  test('Unknown Surah/Juz IDs never generate fabricated page numbers', () {
    expect(quranStartPageForId('quran-0'), isNull);
    expect(quranStartPageForId('quran-115'), isNull);
    expect(quranStartPageForId('juz-0'), isNull);
    expect(quranStartPageForId('juz-31'), isNull);
    expect(quranStartPageForId('mawlid-1'), isNull);
    expect(kExpectedVectorMushafPages, 604);
  });
}
