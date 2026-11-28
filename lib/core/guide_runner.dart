import 'dart:async';

import 'package:flutter/foundation.dart';

import 'guide_flow.dart';
import 'vibration_patterns.dart';

/// Rehber akışını zamanlayıcıyla yürütür. Ekrana dokunmadan ilerler;
/// durdurma her zaman mümkündür.
class GuideRunner extends ChangeNotifier {
  GuideRunner({
    required this.steps,
    required this.onSignal,
    this.onStep,
    this.playAudio,
    this.stopAudio,
    this.speak,
    this.stopSpeech,
  });

  final List<GuideStep> steps;
  final void Function(Signal s) onSignal;
  final void Function(GuideStep s)? onStep;

  /// Adımın kaydını çalar; kayıt bitince tamamlanır. Verilmezse süreye göre.
  final Future<void> Function(List<String> files)? playAudio;
  final Future<void> Function()? stopAudio;

  /// Kayıt yoksa adımın metnini sesli okur; bitince true döner.
  final Future<bool> Function(String text)? speak;
  final Future<void> Function()? stopSpeech;

  /// Kayıt bittikten sonra sonraki adıma geçmeden önce kısa nefes payı.
  static const audioGap = Duration(milliseconds: 700);

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
    final play = playAudio;
    if (s.hasAudio && play != null) {
      play(s.audioFiles).then(
        (_) {
          if (stopped || index != i) return;
          _timer = Timer(audioGap, () => _go(i + 1));
        },
        // Ses çalınamazsa süreye göre devam et.
        onError: (Object _) {
          if (stopped || index != i) return;
          _timer = Timer(s.duration, () => _go(i + 1));
        },
      );
    } else if (s.speech != null && speak != null) {
      final started = DateTime.now();
      speak!(s.speech!).then((ok) {
        if (stopped || index != i) return;
        final spent = DateTime.now().difference(started);
        // Okuma bittikten sonra hareket için en az kısa bir pay bırak;
        // konuşma motoru yoksa adımın kendi süresi kadar bekle.
        final minTotal = ok ? s.duration * 0.5 : s.duration;
        var wait = minTotal - spent;
        if (wait < audioGap) wait = audioGap;
        _timer = Timer(wait, () => _go(i + 1));
      });
    } else {
      _timer = Timer(s.duration, () => _go(i + 1));
    }
  }

  void stop() {
    if (stopped || finished) return;
    stopped = true;
    _timer?.cancel();
    stopAudio?.call();
    stopSpeech?.call();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
