import 'dart:async';

import 'package:flutter/material.dart';

class SpeedSlider extends StatefulWidget {
  final ScrollController controller;

  const SpeedSlider({super.key, required this.controller});

  @override
  SpeedSliderState createState() => SpeedSliderState();
}

class SpeedSliderState extends State<SpeedSlider> {
  static const double gain = 85;

  double push = 0.3;
  bool playing = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void stop() {
    if (!playing) return;
    setState(() => playing = false);
  }

  void _tick(Timer _) {
    if (!playing) return;
    final c = widget.controller;
    if (!c.hasClients) return;
    final max = c.position.maxScrollExtent;
    final next = (c.offset + push * gain * 0.016).clamp(0.0, max);
    c.jumpTo(next);
    if (next >= max) stop();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 2),
        IconButton(
          tooltip: playing ? 'Pause auto-scroll' : 'Play auto-scroll',
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          onPressed: () => setState(() => playing = !playing),
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 18, height: 2, color: scheme.outline),
              RotatedBox(
                quarterTurns: 1,
                child: Semantics(
                  label: 'Auto-scroll speed',
                  child: Slider(
                    min: 0.05,
                    max: 1,
                    value: push,
                    onChanged: (v) => setState(() => push = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
