import 'package:flutter/widgets.dart';

// Native Flutter platforms keep using the existing pdfrx PDF renderer.
Widget webPdfFrame({required String asset, required bool dark}) =>
    const SizedBox.shrink();
