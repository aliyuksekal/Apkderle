import 'dart:async';

import 'package:flutter/foundation.dart';

import 'guide_flow.dart';
import 'vibration_patterns.dart';

/// Rehber akışını zamanlayıcıyla yürütür. Ekrana dokunmadan ilerler;
/// durdurma her zaman mümkündür.
class GuideRunner extends ChangeNotifier {
  GuideRunner({required this.steps, required this.onSignal, this.onStep});

  final List<GuideStep> steps;
  final void Function(Signal s) onSignal;
  final void Function(GuideStep s)? onStep;

  int index = -1;
  bool finished = false;
  bool stopped = false;
  Timer? _timer;

  GuideStep? get current =>
      index >= 0 && index < steps.length ? steps[index] : null;
  bool get running => index >= 0 && !finished && !stopped;

  double get progress => steps.isEmpty ? 0 : (index + 1) / steps.length;

  void start() {
    if (index >= 0) return;
    _go(0);
  }

  void _go(int i) {
    if (stopped) return;
    if (i >= steps.length) {
      finished = true;
      notifyListeners();
      return;
    }
    index = i;
    final s = steps[i];
    if (s.signal != null) onSignal(s.signal!);
    onStep?.call(s);
    notifyListeners();
    _timer = Timer(s.duration, () => _go(i + 1));
  }

  void stop() {
    if (stopped || finished) return;
    stopped = true;
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
