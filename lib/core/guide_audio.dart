import 'audio.dart';
import 'native.dart';

/// Namaz rehberinde hafız kaydını çalar. [play] kayıt bitince tamamlanır.
class GuideAudio {
  Future<void> play(List<String> files) async {
    NativeBridge.instance; // yöntem işleyicisi kurulsun
    final ok = await AssetAudio.instance.play(files);
    if (!ok) throw StateError('ses yok');
  }

  Future<void> stop() => AssetAudio.instance.stop();

  Future<void> dispose() => stop();
}
