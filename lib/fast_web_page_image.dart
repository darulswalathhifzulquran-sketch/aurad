import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Direct browser <img> avoids Flutter asset-manifest/image-decoder failures.
/// Uses the exact URL present in the Netlify build:
/// build/web/assets/assets/{quran_pages|web_books}/name.jpg.
///
/// Each image loads independently; the browser caches it. Theme changes
/// only update the CSS filter, never the URL, so pages never reload.
class FastWebPageImage extends StatefulWidget {
  final String asset;
  final bool dark;
  final bool priority;
  const FastWebPageImage({
    super.key,
    required this.asset,
    required this.dark,
    this.priority = false,
  });

  @override
  State<FastWebPageImage> createState() => _FastWebPageImageState();
}

class _FastWebPageImageState extends State<FastWebPageImage> {
  web.HTMLImageElement? _image;

  void _updateTheme() {
    final image = _image;
    if (image == null) return;
    image.style.filter = widget.dark
        ? 'invert(1) hue-rotate(180deg)'
        : 'none';
    // CSS filter invert(1) also inverts the <img> element's letterbox
    // background. Always start white: dark inversion turns unused image
    // space black instead of leaving bright white bands above/below pages.
    image.style.backgroundColor = '#fff';
    // The original dark source has thin light page-edge lines. Hide only
    // those outermost pixels, not the printed page decorations or text.
    image.style.clipPath = (widget.asset.startsWith('assets/quran_pages/') ||
            widget.asset.startsWith('assets/web_books/dua-4_nov22_page_'))
        ? 'none'
        : (widget.dark ? 'inset(0 1.1% 0 1.1%)' : 'none');
  }

  @override
  void didUpdateWidget(covariant FastWebPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) _updateTheme();
    if (oldWidget.priority != widget.priority && _image != null) {
      _image!.setAttribute('fetchpriority', widget.priority ? 'high' : 'low');
      _image!.setAttribute('loading', widget.priority ? 'eager' : 'lazy');
    }
    if (oldWidget.asset != widget.asset && _image != null) {
      _image!.src = Uri.base.resolve('assets/${widget.asset}?reader=20261117b').toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: ValueKey('native-image-${widget.asset}'),
      tagName: 'img',
      onElementCreated: (Object element) {
        final image = element as web.HTMLImageElement;
        _image = image;
        image.alt = 'Original Arabic book page failed to load: ${widget.asset}';
        image.draggable = false;
        image.style.width = '100%';
        image.style.height = '100%';
        // Always show the COMPLETE original Quran page (surah/juz header,
        // printed page number and all four edges). CSS scaling caused
        // clipped Arabic at the right; object-fit: contain avoids cropping.
        image.style.objectFit = 'contain';
        image.style.transform = 'none';
        image.style.display = 'block';
        image.style.border = '0';
        // Let the surrounding Flutter InteractiveViewer receive touch
        // gestures instead of the native <img> swallowing pinch and drag.
        image.style.pointerEvents = 'none';
        image.style.userSelect = 'none';
        image.setAttribute('decoding', 'async');
        // Only the first/current page gets high network priority; offscreen
        // pages no longer compete with the visible page on slow phones.
        image.setAttribute('loading', widget.priority ? 'eager' : 'lazy');
        image.setAttribute('fetchpriority', widget.priority ? 'high' : 'low');
        _updateTheme();
        if (widget.asset.startsWith('assets/quran_pages/')) {
          // The GitHub Pages bootstrap crops only the empty white margins
          // around the intact green Mushaf panel. Browser-side cropping
          // keeps the 604 original files unchanged and loads pages lazily.
          image.setAttribute('onload',
              'window.riyadPrepareQuranPage && window.riyadPrepareQuranPage(this)');
        }
        image.src = Uri.base.resolve('assets/${widget.asset}').toString();
      },
    );
  }
}
