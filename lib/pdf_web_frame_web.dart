import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Render source PDF files using the browser's built-in PDF viewer on Web.
///
/// This intentionally bypasses PDFium WASM workers on static hosting
/// (Netlify), which may leave a black/empty page if a worker or module
/// fails to initialize. It does not alter the PDF file or paint over its
/// original borders, Arabic text, printed page number or footer.
Widget webPdfFrame({required String asset, required bool dark}) {
  // Flutter puts bundled "assets/books/..." under the browser's
  // "/assets/assets/books/..." URL. Uri.base.resolve works with Netlify
  // and keeps query strings (e.g., tracking parameters) out of the asset URL.
  final pdfUrl = Uri.base.resolve('assets/$asset').toString();
  return HtmlElementView.fromTagName(
    key: ValueKey('browser-pdf-$asset-$dark'),
    tagName: 'iframe',
    onElementCreated: (Object element) {
      final iframe = element as web.HTMLIFrameElement;
      // Chrome/Edge honors toolbar=0, and view=Fit starts with the WHOLE
      // A4 page in view rather than magnifying it to the screen width.
      // No PDF content is modified; only browser display flags change.
      iframe.src = '$pdfUrl#toolbar=0&navpanes=0&view=Fit';
      iframe.title = 'Read the original PDF';
      iframe.style.border = '0';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.style.backgroundColor = dark ? '#000000' : '#ffffff';
      // Keep original file bytes and all printed content unchanged.
      // Theme is visual only, applied to the rendered browser frame.
      if (dark) {
        iframe.style.filter = 'invert(1) hue-rotate(180deg)';
      }
    },
  );
}
