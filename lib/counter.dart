import 'package:flutter/material.dart';
import 'target_vibration_stub.dart' if (dart.library.js_interop) 'target_vibration_web.dart' as vibration;
import 'app_theme.dart';
import 'store.dart';

/// Tasbih counter - dark teal, target presets and large central tap control.
/// Count and target remain persistent through AppState / SharedPreferences.
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  late bool _targetVibration;

  @override
  void initState() {
    super.initState();
    _targetVibration = app.prefs.getBool('target_alert_multiples') ?? true;
  }

  void _tap() {
    final before = app.counter;
    // Alert at *every* positive multiple: 11, 22, 33... or
    // 33, 66, 99... Never alert for the infinity (0) target.
    final completed = app.target > 0 &&
        before < 99999 &&
        (before + 1) % app.target == 0;
    // Play sound / request vibration synchronously within the real tap
    // to satisfy mobile-browser user-gesture restrictions.
    if (completed && _targetVibration) {
      // Browser audio must start synchronously with this user tap.
      // Supported devices will also vibrate.
      vibration.notifyTargetReached();
    }
    app.incCounter();
  }

  Future<void> _setCustomTarget() async {
    // Avoid a TextEditingController disposed during the dialog's exit
    // animation, which can trigger Flutter framework assertions on web.
    var typed = app.target > 0 ? '${app.target}' : '';
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom target'),
        content: TextFormField(
          initialValue: typed,
          autofocus: false,
          keyboardType: TextInputType.number,
          onChanged: (value) => typed = value,
          onFieldSubmitted: (value) => Navigator.of(dialogContext)
              .pop(int.tryParse(value.trim())),
          decoration: const InputDecoration(
            labelText: 'Target count',
            hintText: 'Enter a number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(int.tryParse(typed.trim())),
            child: const Text('Set target'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (selected != null && selected > 0 && selected <= 999999) {
      app.setTarget(selected);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset counter?'),
        content: const Text('Your current dhikr count will become 0.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) app.resetCounter();
  }

  Widget _targetChip(String label, int value) {
    final selected = app.target == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: value == -1 ? _setCustomTarget : () => app.setTarget(value),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: selected
                ? const Color(0xFF193B40)
                : Colors.transparent,
          ),
          child: Text(label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final counter = app.counter;
        final target = app.target;
        final targetText = target == 0 ? '∞' : '$target';
        final customSelected =
            target != 0 && ![11, 33, 100, 313, 1000].contains(target);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Counter'),
            actions: [themeToggleAction()],
          ),
          backgroundColor: app.dark
              ? const Color(0xFF000F10)
              : const Color(0xFFF0F4F3),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  vertical: 20, horizontal: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF052221),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Target',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _targetChip('11', 11),
                          _targetChip('33', 33),
                          _targetChip('100', 100),
                          _targetChip('313', 313),
                          _targetChip('1000', 1000),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: _setCustomTarget,
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: customSelected
                                      ? const Color(0xFF193B40)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Text('Custom',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          ),
                          _targetChip('∞', 0),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF163D48),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Column(
                          children: [
                            const Text('TOTAL DHIKR',
                                style: TextStyle(
                                    color: Color(0xFF87E7FB),
                                    fontSize: 13)),
                            const SizedBox(height: 8),
                            Text('$counter',
                                style: const TextStyle(
                                    fontSize: 29,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text('Target: $targetText',
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF6DDBF6),
                                  fontWeight: FontWeight.w600,
                                )),
                            if (target > 0 && counter >= target) ...[
                              const SizedBox(height: 10),
                              const Text(
                                '✓ TARGET COMPLETED',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF91F4A9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Material(
                          color: const Color(0xFF0789A8),
                          shape: const CircleBorder(
                            side: BorderSide(
                                color: Color(0xFF9CE8FF), width: 5)),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _tap,
                            child: const SizedBox(
                              width: 145,
                              height: 145,
                              child: Center(
                                // Use a literal glyph, not MaterialIcons:
                                // icon tree-shaking left the old + invisible.
                                child: Text(
                                  '+',
                                  semanticsLabel: 'Add one dhikr',
                                  style: TextStyle(
                                    fontFamily: 'Arial',
                                    fontSize: 105,
                                    height: 0.98,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: counter > 0 ? app.undoCounter : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(
                                  color: Color(0xFF335557)),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Undo'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: counter > 0 ? _confirmReset : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(
                                  color: Color(0xFF335557)),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.vibration,
                              color: Color(0xFF6DDBF6), size: 17),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Alert at every target multiple',
                              style: TextStyle(
                                color: Color(0xFF6DDBF6),
                                fontSize: 14,
                              )),
                          ),
                          Checkbox(
                            value: _targetVibration,
                            activeColor: const Color(0xFF86E9FF),
                            checkColor: const Color(0xFF052221),
                            onChanged: (value) {
                              final enabled = value ?? true;
                              setState(() => _targetVibration = enabled);
                              app.prefs.setBool('target_alert_multiples', enabled);
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
