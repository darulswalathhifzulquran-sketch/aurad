import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_auradu/aurad_pdf_book.dart';

void main() {
  testWidgets('Missing devotional PDF shows a safe placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuradPdfBookScreen(
          title: "Swalathus Sa'adha",
          assetPath: 'assets/books/intentionally_missing.pdf',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Swalathus Sa'adha"), findsOneWidget);
    expect(find.text('Content not added yet'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
