import 'package:al_auradu/reference_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the approved Home image and opens its Quran hotspot',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? openedFolder;

    await tester.pumpWidget(
      MaterialApp(
        home: ReferenceHome(
          onFolder: (id) => openedFolder = id,
          onMenu: () {},
          onShare: () {},
          onSearch: () {},
          onOther: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      image.image,
      isA<AssetImage>().having(
        (asset) => asset.assetName,
        'assetName',
        ReferenceHome.imagePath,
      ),
    );

    final quranHotspot = find.bySemanticsLabel('Open Quran');
    expect(quranHotspot, findsOneWidget);
    for (final label in [
      'Dikr',
      'Swalath',
      'Dua',
      'Moulid',
      'Malappatt',
      'Baith',
      'Raatheeb',
      'Majlisunoor',
      'Other',
      'Search',
      'Counter',
    ]) {
      expect(find.bySemanticsLabel('Open $label'), findsOneWidget);
    }

    expect(tester.getSize(find.byType(Stack)).height, lessThanOrEqualTo(640));
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpAndSettle();
    final desktopSize = tester.getSize(find.byType(Stack));
    expect(desktopSize.width, closeTo(600, 1));
    expect(desktopSize.height, closeTo(900, 1));

    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpAndSettle();
    await tester.tap(quranHotspot);
    expect(openedFolder, 'quran');
  });
}
