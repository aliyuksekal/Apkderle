import 'dart:async';

import 'package:flutter/services.dart';

import 'vibration_patterns.dart';

/// Android tarafındaki küçük yerel köprü (titreşim, pusula, ön plan servisi).
/// Kotlin kodu: android/app/src/main/kotlin/.../MainActivity.kt
class NativeBridge {
  NativeBridge._() {
    _method.setMethodCallHandler((call) async {
      if (call.method == 'guideStopRequested') {
        _stopRequests.add(null);
      }
      return null;
    });
  }

  static final NativeBridge instance = NativeBridge._();

  static const _method = MethodChannel('namaz/native');
  static const _compass = EventChannel('namaz/compass');

  final _stopRequests = StreamController<void>.broadcast();

  /// Kullanıcı bildirimdeki "Durdur" düğmesine bastığında tetiklenir.
  Stream<void> get guideStopRequests => _stopRequests.stream;

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await _method.invokeMethod<T>(m, args);
    } on MissingPluginException {
      return null; // test ortamı / desteklenmeyen platform
    } on PlatformException {
      return null;
    }
  }

  Future<bool> hasVibrator() async => await _call<bool>('hasVibrator') ?? false;

  /// [strong]: alarm kullanımıyla titreşir (ekran kapalıyken de hissedilsin).
  Future<void> vibrate(Signal s, {bool strong = false}) =>
      _call('vibrate', {'pattern': s.pattern, 'strong': strong});

  /// Kısa ses: 'tap' | 'goal' | 'test'
  Future<void> tone(String kind) => _call('tone', {'kind': kind});

  Future<void> startGuideService(String title) =>
      _call('startGuideService', {'title': title});

  Future<void> updateGuideService(String text) =>
      _call('updateGuideService', {'text': text});

  Future<void> stopGuideService() => _call('stopGuideService');

  Future<void> requestNotificationPermission() =>
      _call('requestNotificationPermission');

  Future<void> keepScreenOn(bool on) => _call('keepScreenOn', {'on': on});

  /// Manyetik sapma düzeltmesi için konum bildir.
  Future<void> setCompassLocation(double lat, double lng) =>
      _call('setCompassLocation', {'lat': lat, 'lng': lng});

  Future<void> openAppSettings() => _call('openAppSettings');

  /// Coğrafi kuzeye göre yön (derece) ve doğruluk (0=güvenilmez … 3=yüksek).
  Stream<CompassReading> compass() => _compass
      .receiveBroadcastStream()
      .map((e) => CompassReading.fromMap(Map<Object?, Object?>.from(e as Map)));
}

class CompassReading {
  CompassReading(this.heading, this.accuracy);
  factory CompassReading.fromMap(Map<Object?, Object?> m) => CompassReading(
        (m['heading'] as num).toDouble(),
        (m['accuracy'] as num).toInt(),
      );

  final double heading;
  final int accuracy;

  bool get needsCalibration => accuracy < 2;
}
