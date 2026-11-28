import 'dart:async';

import 'package:flutter/services.dart';

/// Uygulama içindeki ses dosyalarını Android'in kendi oynatıcısıyla çalar
/// (internet gerekmez). Kotlin tarafı: AssetAudio.kt
class AssetAudio {
  AssetAudio._();
  static final AssetAudio instance = AssetAudio._();

  static const _ch = MethodChannel('namaz/native');

  int _token = 0;
  Completer<bool>? _done;

  /// Kullanıcıya gösterilecek ses sorunları (sessiz telefon, hata).
  final _problems = StreamController<String>.broadcast();
  Stream<String> get problems => _problems.stream;

  /// NativeBridge yöntem işleyicisinden çağrılır.
  void onNativeEvent(Map<Object?, Object?> m) {
    if (m['token'] != _token) return;
    final c = _done;
    _done = null;
    if (m['event'] == 'error') {
      _problems.add('Ses çalınamadı. ${m['detail'] ?? ''}'.trim());
      c?.complete(false);
    } else {
      c?.complete(true);
    }
  }

  /// [files] sırayla çalınır. Liste bitince true, durdurulur ya da hata
  /// olursa false döner.
  Future<bool> play(List<String> files, {double speed = 1.0}) async {
    _finish(false);
    if (files.isEmpty) return true;
    final tok = ++_token;
    final c = _done = Completer<bool>();
    try {
      final vol = await _ch.invokeMethod<int>('audioPlay', {
        'files': files,
        'token': tok,
        'speed': speed,
      });
      if (vol == 0) {
        _problems.add('Telefonun medya sesi kapalı. Ses tuşuyla sesi açın.');
      }
    } on MissingPluginException {
      _finish(false);
    } on PlatformException catch (e) {
      _problems.add('Ses çalınamadı: ${e.message}');
      _finish(false);
    }
    return c.future;
  }

  void _finish(bool v) {
    final c = _done;
    _done = null;
    if (c != null && !c.isCompleted) c.complete(v);
  }

  Future<void> stop() async {
    _token++;
    _finish(false);
    try {
      await _ch.invokeMethod('audioStop');
    } on MissingPluginException {
      // test ortamı
    }
  }
}
