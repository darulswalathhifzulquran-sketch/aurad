import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Browser PDF plugin stays mounted across dark/light changes.
/// The source is loaded once; changing appearance never navigates the iframe
/// or displays the blank white/grey loading frame again.
Widget webPdfFrame({required String asset, required bool dark}) =>
    _StableBrowserPdf(key: ValueKey('browser-pdf-$asset'), asset: asset, dark: dark);

class _StableBrowserPdf extends StatefulWidget {
  final String asset;
  final bool dark;
  const _StableBrowserPdf({super.key, required this.asset, required this.dark});

  @override
  State<_StableBrowserPdf> createState() => _StableBrowserPdfState();
}

class _StableBrowserPdfState extends State<_StableBrowserPdf> {
  web.HTMLIFrameElement? _iframe;

  void _applyTheme() {
    final iframe = _iframe;
    if (iframe == null) return;
    iframe.style.backgroundColor = widget.dark ? '#000000' : '#ffffff';
    // CSS only: PDF original bytes, Arabic, decoration and footer untouched.
    // Never change src on a theme toggle (that triggers a full PDF reload).
    iframe.style.filter =
        widget.dark ? 'invert(1) hue-rotate(180deg)' : 'none';
  }

  @override
  void didUpdateWidget(covariant _StableBrowserPdf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) _applyTheme();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      child: HtmlElementView.fromTagName(
        key: ValueKey('pdf-html-${widget.asset}'),
        tagName: 'iframe',
        onElementCreated: (Object element) {
          final iframe = element as web.HTMLIFrameElement;
          _iframe = iframe;
          iframe.title = 'Read original PDF';
          iframe.style.border = '0';
          iframe.style.width = '100%';
          iframe.style.height = '100%';
          iframe.style.display = 'block';
          _applyTheme();
          final pdfUrl = Uri.base.resolve('assets/${widget.asset}').toString();
          // Fit = the entire A4 sheet; no print/download/zoom toolbar.
          iframe.src = '$pdfUrl#toolbar=0&navpanes=0&view=Fit';
        },
      ),
    );
  }
}
