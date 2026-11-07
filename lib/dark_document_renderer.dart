import 'package:flutter/material.dart';

const ColorFilter darkDocumentColorFilter = ColorFilter.matrix([
  -1,
  0,
  0,
  0,
  255,
  0,
  -1,
  0,
  0,
  255,
  0,
  0,
  -1,
  0,
  255,
  0,
  0,
  0,
  1,
  0,
]);

ColorFilter? darkDocumentColorFilterFor(bool dark) =>
    dark ? darkDocumentColorFilter : null;

const Color darkDocumentTitleColor = Color(0xFFEBCB84);
