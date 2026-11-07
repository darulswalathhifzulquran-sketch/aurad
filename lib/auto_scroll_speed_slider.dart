import 'package:flutter/material.dart';

class AutoScrollSpeedSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const AutoScrollSpeedSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 36,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const arrowHeight = 24.0;
          const thumbSize = 18.0;
          final trackHeight = (constraints.maxHeight - arrowHeight * 2)
              .clamp(0.0, double.infinity)
              .toDouble();
          final thumbTravel =
              (trackHeight - thumbSize).clamp(0.0, double.infinity).toDouble();
          final thumbTop = arrowHeight + thumbTravel * normalized;

          void updateFromY(double y) {
            if (thumbTravel <= 0) return;
            final thumbCenter = (y - arrowHeight).clamp(
              thumbSize / 2,
              trackHeight - thumbSize / 2,
            );
            onChanged(((thumbCenter - thumbSize / 2) / thumbTravel)
                .clamp(0.0, 1.0)
                .toDouble());
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: arrowHeight,
                bottom: arrowHeight,
                child: SizedBox(
                  width: 28,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (details) =>
                        updateFromY(details.localPosition.dy + arrowHeight),
                    onVerticalDragUpdate: (details) =>
                        updateFromY(details.localPosition.dy + arrowHeight),
                    onTapDown: (details) =>
                        updateFromY(details.localPosition.dy + arrowHeight),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          top: thumbSize / 2,
                          bottom: thumbSize / 2,
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF555B61),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          top: thumbTop - arrowHeight,
                          child: Semantics(
                            label: 'Automatic scrolling speed',
                            value:
                                '${(normalized * 20).round()} pixels per second',
                            slider: true,
                            onIncrease: () => onChanged(
                                (normalized + 0.05).clamp(0.0, 1.0).toDouble()),
                            onDecrease: () => onChanged(
                                (normalized - 0.05).clamp(0.0, 1.0).toDouble()),
                            child: Container(
                              width: thumbSize,
                              height: thumbSize,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8FD3F4),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                width: 28,
                height: arrowHeight,
                child: Icon(Icons.keyboard_arrow_up, size: 18),
              ),
              const Positioned(
                bottom: 0,
                width: 28,
                height: arrowHeight,
                child: Icon(Icons.keyboard_arrow_down, size: 18),
              ),
            ],
          );
        },
      ),
    );
  }
}
