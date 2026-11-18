import 'package:flutter/material.dart';

/// Pinch-to-zoom and drag-to-pan on a PDF/Quran page. No zoom slider.
/// At normal scale the parent PageView/ListView retains scrolling gestures.
/// Double-tap toggles 1x / 2x on platforms where pinch is unavailable.
class ZoomablePage extends StatefulWidget {
  final Widget child;
  const ZoomablePage({super.key, required this.child});

  @override
  State<ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<ZoomablePage> {
  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    _transform.value = _zoomed
        ? Matrix4.identity()
        : Matrix4.diagonal3Values(2, 2, 1);
    setState(() => _zoomed = !_zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(120),
        clipBehavior: Clip.hardEdge,
        panEnabled: _zoomed,
        onInteractionUpdate: (_) {
          final zoomed = _transform.value.getMaxScaleOnAxis() > 1.015;
          if (_zoomed != zoomed && mounted) setState(() => _zoomed = zoomed);
        },
        child: widget.child,
      ),
    );
  }
}
