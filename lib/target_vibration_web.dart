import 'dart:js_interop';

/// Android Chrome supports navigator.vibrate after a direct user tap.
/// Browsers that do not support it (notably iOS Safari) ignore the request.
@JS('navigator.vibrate')
external JSBoolean _browserVibrate(JSArray<JSNumber> pattern);

void vibrateForTarget() {
  try {
    _browserVibrate(<int>[200, 100, 200].map((n) => n.toJS).toList().toJS);
  } catch (_) {
    // Vibration support depends on the browser, device and user settings.
  }
}

@JS('riyadTargetSound')
external void _playTargetSound();

/// Trigger from the actual counter tap. WebAudio will play on desktops,
/// smart boards and phones with working speakers; vibration is best effort.
void notifyTargetReached() {
  try {
    _playTargetSound();
  } catch (_) {
    // Browser sound is optional (blocked, unsupported or muted).
  }
  vibrateForTarget();
}
