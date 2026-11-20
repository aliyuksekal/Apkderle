import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Namaz rehberinde hafız kaydını ayet ayet çalar. [play] tüm dosyalar
/// bitince tamamlanır; [stop] çağrılırsa hemen tamamlanır.
class GuideAudio {
  AudioPlayer? _player;
  Completer<void>? _done;
  List<String> _files = const [];
  int _i = 0;
  StreamSubscription<void>? _sub;

  AudioPlayer _ensure() {
    final p = _player ??= AudioPlayer()..audioCache = AudioCache(prefix: '');
    _sub ??= p.onPlayerComplete.listen((_) => _next());
    return p;
  }

  Future<void> play(List<String> files) async {
    _finish();
    _files = files;
    _i = -1;
    final c = _done = Completer<void>();
    await _next();
    return c.future;
  }

  Future<void> _next() async {
    _i++;
    if (_i >= _files.length) {
      _finish();
      return;
    }
    try {
      await _ensure().play(AssetSource(_files[_i]));
    } catch (e) {
      final c = _done;
      _done = null;
      if (c != null && !c.isCompleted) c.completeError(e);
    }
  }

  void _finish() {
    final c = _done;
    _done = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> stop() async {
    _files = const [];
    _finish();
    await _player?.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _sub?.cancel();
    await _player?.dispose();
  }
}
