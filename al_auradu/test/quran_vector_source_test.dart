import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Original 604-page Quran PDF is actually present, not an LFS pointer',
      () async {
    final file = File('assets/books/quran_vector_604.pdf');
    expect(await file.exists(), isTrue,
        reason: 'Run git lfs pull to download the original 604-page vector PDF.');
    final size = await file.length();
    expect(size, greaterThan(1000000),
        reason: 'The Git LFS pointer is only 134 bytes; download real PDF.');
    final header = await file.openRead(0, 5).first;
    expect(String.fromCharCodes(header), '%PDF-',
        reason: 'Quran must be a genuine, original-source PDF document.');
  });
}
