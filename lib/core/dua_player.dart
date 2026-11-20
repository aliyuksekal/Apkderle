import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'duas.dart';

/// Hafız kayıtlarını sırayla çalar (bir dua ya da tüm dualar).
/// Oynatıcı ilk kullanımda oluşturulur.
class DuaPlayer extends ChangeNotifier {
  DuaPlayer._();
  static final DuaPlayer instance = DuaPlayer._();

  AudioPlayer? _player;
  StreamSubscription<void>? _done;

  List<(Dua, int)> _queue = const [];
  int _pos = -1;

  bool get playing => _pos >= 0 && _pos < _queue.length;
  Dua? get currentDua => playing ? _queue[_pos].$1 : null;
  int get currentVerse => playing ? _queue[_pos].$2 : -1;
  bool isPlayingDua(Dua d) => currentDua?.id == d.id;

  AudioPlayer _ensure() {
    final p = _player ??= AudioPlayer()..audioCache = AudioCache(prefix: '');
    _done ??= p.onPlayerComplete.listen((_) => _next());
    return p;
  }

  Future<void> playDua(Dua d) => _start([d]);

  Future<void> playAll(List<Dua> list) =>
      _start(list.where((d) => d.hasAudio).toList());

  Future<void> _start(List<Dua> duas) async {
    final q = <(Dua, int)>[];
    for (final d in duas) {
      for (var i = 0; i < d.verses.length; i++) {
        if (d.verses[i].audio != null) q.add((d, i));
      }
    }
    if (q.isEmpty) return;
    await _player?.stop();
    _queue = q;
    _pos = -1;
    await _next();
  }

  Future<void> _next() async {
    _pos++;
    notifyListeners();
    if (!playing) {
      _queue = const [];
      _pos = -1;
      notifyListeners();
      return;
    }
    final (d, i) = _queue[_pos];
    try {
      await _ensure().play(AssetSource(d.verses[i].audio!));
    } catch (_) {
      await stop();
    }
  }

  Future<void> stop() async {
    _queue = const [];
    _pos = -1;
    notifyListeners();
    await _player?.stop();
  }
}
