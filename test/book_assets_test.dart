import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the approved home artwork is bundled', () async {
    final bytes =
        await rootBundle.load('assets/images/aurad_reference_home.png');
    expect(bytes.lengthInBytes, greaterThan(1000000));
  });

  test('the three Swalath PDFs are bundled against their existing entries',
      () async {
    final library =
        jsonDecode(await rootBundle.loadString('assets/data/library.json'))
            as Map<String, dynamic>;
    final items = (library['items'] as List)
        .cast<Map<String, dynamic>>()
        .where((item) => item['pdfAsset'] != null)
        .toList();
    final assetsById = {
      for (final item in items) item['id']: item['pdfAsset'],
    };

    expect(assetsById, {
      'swalath-saadha': 'assets/books/swalathu_saadha.pdf',
      'swalath-3': 'assets/books/swalathu_taj.pdf',
      'swalath-4': 'assets/books/swalathu_nariyath.pdf',
    });

    for (final asset in assetsById.values.cast<String>()) {
      final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
      expect(bytes.length, greaterThan(5));
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    }
  });

  test('all extra document page images are bundled', () async {
    final extras =
        jsonDecode(await rootBundle.loadString('assets/extra_items.json'))
            as List;
    final imageAssets = <String>{};
    for (final item in extras.cast<Map<String, dynamic>>()) {
      for (final page in (item['pages'] as List).cast<Map<String, dynamic>>()) {
        for (final block
            in (page['blocks'] as List).cast<Map<String, dynamic>>()) {
          if (block['t'] == 'image') imageAssets.add(block['asset'] as String);
        }
      }
    }

    expect(imageAssets, isNotEmpty);
    for (final asset in imageAssets) {
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0),
          reason: asset);
    }
  });

  test('the approved Quran border and original Quran source are bundled',
      () async {
    expect(
      (await rootBundle.load('assets/images/quran_border.png')).lengthInBytes,
      greaterThan(0),
    );
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(manifest.listAssets(), contains('quran.pdf'));
    final quranMetadata =
        jsonDecode(await rootBundle.loadString('assets/quran - Copy/info.json'))
            as Map<String, dynamic>;
    expect(quranMetadata['count'], 604);
  });
}
