import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_auradu/reference_home.dart';

void main() {
  testWidgets('Reference home exposes twelve interactive destinations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var selected = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReferenceHome(
          onFolder: (id) => selected = id,
          onMenu: () {},
          onShare: () {},
          onSearch: () => selected = 'search',
          onOther: () => selected = 'other',
        ),
      ),
    ));
    await tester.pump();

    for (final label in [
      'Quran', 'Dikr', 'Swalath', 'Dua',
      'Moulid', 'Malappatt', 'Baith', 'Raatheeb',
      'Majlisunoor', 'Other', 'Search', 'Counter'
    ]) {
      expect(find.bySemanticsLabel('Open $label'), findsOneWidget);
    }
    await tester.tap(find.bySemanticsLabel('Open Quran'));
    expect(selected, 'quran');
  });
}
