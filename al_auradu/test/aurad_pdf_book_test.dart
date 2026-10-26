import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:al_auradu/aurad_pdf_book.dart';

void main() {
  testWidgets('PDF reader opens app bar immediately without double-loading',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuradPdfBookScreen(
          title: "Swalathu Sa'adha",
          assetPath: 'assets/books/swalathus_saadha.pdf',
        ),
      ),
    );

    // The UI must appear on the first frame, regardless of how long the
    // asynchronous PDF renderer takes to initialise in the browser.
    expect(find.text("Swalathu Sa'adha"), findsOneWidget);
    expect(find.byType(PdfViewer), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
