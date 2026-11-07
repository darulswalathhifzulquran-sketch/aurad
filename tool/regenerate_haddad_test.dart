import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate and decode all cleaned page assets', () async {
    const crops = <String, double>{
      'haddad_012': 0.80,
      'muhyi_032': 0.87,
      'nafeesa_030': 0.48,
    };

    for (final entry in crops.entries) {
      final data = await rootBundle.load('assets/pages/${entry.key}.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final source = (await codec.getNextFrame()).image;
      final cropHeight = (source.height * entry.value).round();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(0, 0, source.width.toDouble(), cropHeight.toDouble()),
        ui.Rect.fromLTWH(0, 0, source.width.toDouble(), cropHeight.toDouble()),
        ui.Paint(),
      );
      final picture = recorder.endRecording();
      final cleaned = await picture.toImage(source.width, cropHeight);
      final png = await cleaned.toByteData(format: ui.ImageByteFormat.png);
      expect(png, isNotNull);
      final bytes = png!.buffer.asUint8List();
      final outputCodec = await ui.instantiateImageCodec(bytes);
      final output = (await outputCodec.getNextFrame()).image;
      expect(output.width, source.width);
      expect(output.height, cropHeight);
      await File('assets/pages/${entry.key}_clean.png')
          .writeAsBytes(bytes, flush: true);
      source.dispose();
      cleaned.dispose();
      output.dispose();
      picture.dispose();
      codec.dispose();
      outputCodec.dispose();
    }

    final sourceData = await rootBundle.load('assets/pages/rifai_036.webp');
    final sourceCodec =
        await ui.instantiateImageCodec(sourceData.buffer.asUint8List());
    final source = (await sourceCodec.getNextFrame()).image;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(
      const ui.Color(0xFFFFFFFF),
      ui.BlendMode.src,
    );
    final picture = recorder.endRecording();
    final cleaned = await picture.toImage(source.width, source.height);
    final png = await cleaned.toByteData(format: ui.ImageByteFormat.png);
    expect(png, isNotNull);
    final bytes = png!.buffer.asUint8List();
    final outputCodec = await ui.instantiateImageCodec(bytes);
    final output = (await outputCodec.getNextFrame()).image;
    expect(output.width, source.width);
    expect(output.height, source.height);
    await File('assets/pages/rifai_036_clean.png')
        .writeAsBytes(bytes, flush: true);
    source.dispose();
    cleaned.dispose();
    output.dispose();
    picture.dispose();
    sourceCodec.dispose();
    outputCodec.dispose();
  });
}