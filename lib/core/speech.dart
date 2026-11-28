import 'dart:async';

import 'package:flutter/services.dart';

/// Telefonun Türkçe konuşma motoruyla sesli okuma (internetsiz, ses paketi
/// telefonda yüklüyse). Kotlin tarafı: Speaker.kt
class Speech {
  Speech._();
  static final Speech instance = Speech._();

  static const _ch = MethodChannel('namaz/native');
  int _token = 0;
  Completer<bool>? _done;

  void onNativeEvent(Map<Object?, Object?> m) {
    if (m['token'] != _token) return;
    final c = _done;
    _done = null;
    if (c != null && !c.isCompleted) c.complete(true);
  }

  /// Okur; bitince true. Motor yoksa ya da durdurulursa false.
  Future<bool> speak(String text, {double rate = 1.0}) async {
    _finish(false);
    final t = text.trim();
    if (t.isEmpty) return true;
    final tok = ++_token;
    final c = _done = Completer<bool>();
    try {
      final ok = await _ch.invokeMethod<bool>('ttsSpeak', {
        'text': t,
        'rate': rate,
        'token': tok,
      });
      if (ok == false) _finish(false);
    } on MissingPluginException {
      _finish(false);
    } on PlatformException {
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
      await _ch.invokeMethod('ttsStop');
    } on MissingPluginException {
      // test ortamı
    }
  }

  /// Türkçe ses paketi hazır mı? (null: bilinmiyor / test ortamı)
  Future<bool?> turkishReady() async {
    try {
      final m = await _ch.invokeMethod<Map<Object?, Object?>>('ttsStatus');
      if (m == null) return null;
      if (m['ready'] != true) return null; // henüz başlatılıyor
      return m['turkish'] == true;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> openSettings() async {
    try {
      await _ch.invokeMethod('openTtsSettings');
    } on MissingPluginException {
      // test ortamı
    }
  }
}
