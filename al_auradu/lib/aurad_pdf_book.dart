import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

/// Original-PDF reader: never turns religious content into low-resolution PNGs.
/// PDF pages are rendered by PDFium at the viewer's current zoom scale.
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
  late Future<void> _assetCheck;

  @override
  void initState() {
    super.initState();
    _assetCheck = _checkAsset();
  }

  Future<void> _checkAsset() async {
    // Fail gracefully when a new book is registered but its PDF is not
    // committed yet. Re-throw so FutureBuilder can show the empty state.
    await rootBundle.load(widget.assetPath);
  }

  void _retry() {
    setState(() => _assetCheck = _checkAsset());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<void>(
        future: _assetCheck,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 46),
                    const SizedBox(height: 16),
                    const Text(
                      'Content not added yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The original PDF will appear here after it is added '
                      'to the app assets.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return PdfViewer.asset(
            widget.assetPath,
            // Native gestures: pinch to zoom, pan, and vertical page scroll.
            // No low-DPI image conversion or fixed-resolution screenshots.
          );
        },
      ),
    );
  }
}
