import 'package:flutter/foundation.dart';

import 'audio.dart';
import 'duas.dart';
import 'native.dart';

/// Duaları ayet ayet çalar (bir dua ya da sıradaki dualar).
class DuaPlayer extends ChangeNotifier {
  DuaPlayer._();
  static final DuaPlayer instance = DuaPlayer._();

  List<(Dua, int)> _queue = const [];
  int _pos = -1;
  int _run = 0;

  bool get playing => _pos >= 0 && _pos < _queue.length;
  Dua? get currentDua => playing ? _queue[_pos].$1 : null;
  int get currentVerse => playing ? _queue[_pos].$2 : -1;
  bool isPlayingDua(Dua d) => currentDua?.id == d.id;

  Future<void> playDua(Dua d, {int fromVerse = 0}) =>
      _start([d], fromVerse: fromVerse);

  Future<void> playAll(List<Dua> list) =>
      _start(list.where((d) => d.hasAudio).toList());

  Future<void> _start(List<Dua> duas, {int fromVerse = 0}) async {
    NativeBridge.instance; // olay işleyicisi kurulsun
    final q = <(Dua, int)>[];
    for (final d in duas) {
      for (var i = duas.length == 1 ? fromVerse : 0; i < d.verses.length; i++) {
        if (d.verses[i].audio != null) q.add((d, i));
      }
    }
    if (q.isEmpty) return;
    final run = ++_run;
    _queue = q;
    for (_pos = 0; _pos < _queue.length; _pos++) {
      notifyListeners();
      final (d, i) = _queue[_pos];
      final ok = await AssetAudio.instance.play([d.verses[i].audio!]);
      if (!ok || run != _run) break;
    }
    if (run == _run) {
      _queue = const [];
      _pos = -1;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _run++;
    _queue = const [];
    _pos = -1;
    notifyListeners();
    await AssetAudio.instance.stop();
  }
}
