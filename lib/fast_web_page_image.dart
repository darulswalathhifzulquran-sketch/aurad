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
  const FastWebPageImage({
    super.key,
    required this.asset,
    required this.dark,
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
    image.style.backgroundColor = widget.dark ? '#000' : '#fff';
  }

  @override
  void didUpdateWidget(covariant FastWebPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) _updateTheme();
    if (oldWidget.asset != widget.asset && _image != null) {
      _image!.src = Uri.base.resolve('assets/${widget.asset}').toString();
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
        image.alt = 'Original Arabic book page';
        image.draggable = false;
        image.style.width = '100%';
        image.style.height = '100%';
        image.style.objectFit = 'contain';
        image.style.display = 'block';
        image.style.border = '0';
        _updateTheme();
        image.src = Uri.base.resolve('assets/${widget.asset}').toString();
      },
    );
  }
}
