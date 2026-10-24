import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_auradu/aurad_theme.dart';

void main() {
  test('light and dark themes keep their required outer backgrounds', () {
    expect(AuradTheme.light().scaffoldBackgroundColor, AuradColors.mint);
    expect(AuradTheme.dark().scaffoldBackgroundColor, Colors.black);
  });

  testWidgets('neumorphic folder surface remains tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AuradTheme.light(),
        home: Scaffold(
          body: Center(
            child: AuradPanel(
              onTap: () => tapped = true,
              child: const Text('Open library'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open library'));
    expect(tapped, isTrue);
  });
}
