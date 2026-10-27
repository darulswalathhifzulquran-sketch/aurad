import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Display an original vector PDF using PDFium.
/// The old implementation loaded the whole asset with rootBundle first,
/// then PdfViewer.asset fetched it again. This version loads it ONCE.
class AuradPdfBookScreen extends StatefulWidget {
  const AuradPdfBookScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<AuradPdfBookScreen> createState() => _AuradPdfBookScreenState();
}

class _AuradPdfBookScreenState extends State<AuradPdfBookScreen> {
  final _viewer = PdfViewerController();
  Timer? _timer;
  bool _scroll = false;
  bool _dark = false;
  double _speed = 0.8;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _toggle() {
    _timer?.cancel();
    setState(() => _scroll = !_scroll);
    if (!_scroll) return;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || !_viewer.isReady) return;
      final visible = _viewer.visibleRect;
      final maxY = _viewer.documentSize.height - visible.height;
      if (visible.top >= maxY) {
        _timer?.cancel();
        if (mounted) setState(() => _scroll = false);
        return;
      }
      _viewer.goToPosition(documentOffset: Offset(visible.left,
        (visible.top + _speed).clamp(0.0, maxY < 0 ? 0.0 : maxY)),
        duration: Duration.zero);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: _scroll ? 'Pause scrolling' : 'Slow auto-scroll',
            icon: Icon(_scroll ? Icons.pause_circle : Icons.play_circle), onPressed: _toggle),
          IconButton(tooltip: 'Dark mode',
            icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _dark = !_dark)),
        ],
      ),
      body: Column(children: [
        SizedBox(height: 35, child: Row(children: [
          const SizedBox(width: 8), const Text('Slow scroll'),
          Expanded(child: Slider(value: _speed, min: 0.2, max: 2.0,
            onChanged: (v) => setState(() => _speed = v))),
        ])),
        Expanded(child: PdfViewer.asset(
        widget.assetPath,
        controller: _viewer,
        useProgressiveLoading: true,
        params: PdfViewerParams(
          // Open with the whole page on screen, not an enlarged top crop.
          calculateInitialZoom:
              (document, controller, fitZoom, coverZoom) => fitZoom,
          backgroundColor: _dark ? Colors.black : const Color(0xFF15273E),
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
      )),
    ]));
  }
}
