import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_auradu/dark_document_renderer.dart';

void main() {
  test('dark documents use the shared reversible color treatment', () {
    expect(darkDocumentColorFilterFor(true), darkDocumentColorFilter);
    expect(darkDocumentColorFilterFor(false), isNull);
    expect(darkDocumentTitleColor, const Color(0xFFEBCB84));
  });
}
