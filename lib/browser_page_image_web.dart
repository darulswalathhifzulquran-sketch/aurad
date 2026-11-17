import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// A real browser <img>, not a Flutter CanvasKit-decoded image.
/// The src is a direct, same-origin Netlify asset URL, so Chrome/Edge
/// renders immediately when the JPEG arrives. Original page pixels,
/// Arabic glyphs, borders and footer are kept intact.
/// Dark/light is CSS-only and NEVER downloads the image again.
class BrowserPageImage extends StatefulWidget {
  final String asset;
  final bool dark;
  const BrowserPageImage({
    super.key,
    required this.asset,
    required this.dark,
  });

  @override
  State<BrowserPageImage> createState() => _BrowserPageImageState();
}

class _BrowserPageImageState extends State<BrowserPageImage> {
  web.HTMLImageElement? _image;

  void _updateStyle() {
    final img = _image;
    if (img == null) return;
    img.style.filter = widget.dark ? 'invert(1) hue-rotate(180deg)' : 'none';
    img.style.backgroundColor = widget.dark ? '#000000' : '#ffffff';
  }

  @override
  void didUpdateWidget(covariant BrowserPageImage old) {
    super.didUpdateWidget(old);
    if (old.dark != widget.dark) _updateStyle();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: ValueKey('native-img-${widget.asset}'),
      tagName: 'img',
      onElementCreated: (Object element) {
        final img = element as web.HTMLImageElement;
        _image = img;
        img.alt = 'Original PDF page is unavailable: ${widget.asset}';
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = 'contain';
        img.style.display = 'block';
        _updateStyle();
        // Flutter Web stores declared images in /assets/assets/...
        // Load the real JPEG, never the Netlify SPA HTML fallback.
        img.src = Uri.base.resolve('assets/${widget.asset}').toString();
      },
    );
  }
}
