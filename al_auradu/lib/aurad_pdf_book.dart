import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Display an original vector PDF using PDFium.
/// The old implementation loaded the whole asset with rootBundle first,
/// then PdfViewer.asset fetched it again. This version loads it ONCE.
class AuradPdfBookScreen extends StatelessWidget {
  const AuradPdfBookScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: PdfViewer.asset(
        assetPath,
        useProgressiveLoading: true,
        params: PdfViewerParams(
          // Open with the whole page on screen, not an enlarged top crop.
          calculateInitialZoom:
              (document, controller, fitZoom, coverZoom) => fitZoom,
          backgroundColor: const Color(0xFF15273E),
          margin: 12,
          // Smaller first render makes the reader react faster;
          // PDFium subsequently re-renders high-detail/vector content
          // at the actual zoom scale.
          onePassRenderingSizeThreshold: 1600,
          limitRenderingCache: true,
          loadingBannerBuilder: (context, downloaded, total) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Opening PDF...'),
                ],
              ),
            );
          },
          errorBannerBuilder: (context, error, stack, documentRef) =>
              const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, size: 46),
                  SizedBox(height: 16),
                  Text(
                    'Content not added yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'The PDF could not be opened. Please check its asset file.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
