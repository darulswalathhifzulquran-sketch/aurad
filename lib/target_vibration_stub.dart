import 'package:flutter/services.dart';

void vibrateForTarget() {
  HapticFeedback.heavyImpact();
}

void notifyTargetReached() {
  // Native mobile devices use system alert/haptic feedback when available.
  SystemSound.play(SystemSoundType.alert);
  vibrateForTarget();
}
