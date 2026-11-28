import 'dart:async';

import 'package:flutter/services.dart';

/// Telefonun Türkçe konuşma motoruyla sesli okuma (internetsiz, ses paketi
/// telefonda yüklüyse). Kotlin tarafı: Speaker.kt
class Speech {
  Speech._();
  static final Speech instance = Speech._();

  static const _ch = MethodChannel('namaz/native');

  /// Seçili ses adı ('' = otomatik: bulunursa erkek ses).
  String voice = '';

  /// Ses kalınlığı (1.0 normal; daha küçük = daha kalın, erkek sesine yakın).
  double pitch = 0.85;
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
        'pitch': pitch,
        'voice': voice,
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

  /// Telefondaki Türkçe sesler.
  Future<List<TtsVoice>> voices() async {
    try {
      final l = await _ch.invokeMethod<List<Object?>>('ttsVoices') ?? const [];
      return [
        for (final e in l.cast<Map<Object?, Object?>>())
          TtsVoice(
            e['name'] as String,
            male: e['male'] as bool?,
            network: e['network'] == true,
          ),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
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

class TtsVoice {
  const TtsVoice(this.name, {this.male, this.network = false});
  final String name;
  final bool? male;
  final bool network;
}
