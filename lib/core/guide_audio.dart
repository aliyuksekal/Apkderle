import 'audio.dart';
import 'guide_flow.dart';
import 'native.dart';

/// Namaz rehberinde hafız kaydını çalar. [play] kayıt bitince tamamlanır.
class GuideAudio {
  GuideAudio({this.speed = 1.0, this.hocaSpeed = 1.0});

  /// Hafız kaydının çalma hızı.
  final double speed;

  /// Hocanın dua kayıtlarının çalma hızı (doğal hıza yakın tutulur).
  final double hocaSpeed;

  Future<void> play(List<String> files) async {
    NativeBridge.instance; // yöntem işleyicisi kurulsun
    final ok = await AssetAudio.instance.play(
      files,
      speed: files.every(isHocaAudio) ? hocaSpeed : speed,
    );
    if (!ok) throw StateError('ses yok');
  }

  Future<void> stop() => AssetAudio.instance.stop();

  Future<void> dispose() => stop();
}
