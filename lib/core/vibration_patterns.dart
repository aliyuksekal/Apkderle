/// Titreşim dili. Desenler Android dalga biçimi olarak verilir:
/// [bekle, titreş, bekle, titreş, ...] milisaniye.
enum Signal {
  /// Zikirmatik dokunuşu — çok kısa.
  tap,

  /// 1 kısa = rükûya geçiş.
  ruku,

  /// 2 kısa = secdeye geçiş.
  secde,

  /// 1 uzun = oturma / kalkma geçişi.
  transition,

  /// 3 uzun = namaz rehberi tamamlandı.
  done,

  /// Zikir hedefi tamamlandı ("Maşallah").
  zikrGoal,
}

const int kShort = 180;
const int kLong = 700;
const int kGap = 220;

extension SignalX on Signal {
  List<int> get pattern => switch (this) {
    Signal.tap => const [0, 35],
    Signal.ruku => const [0, kShort],
    Signal.secde => const [0, kShort, kGap, kShort],
    Signal.transition => const [0, kLong],
    Signal.done => const [0, kLong, 350, kLong, 350, kLong],
    Signal.zikrGoal => const [0, 120, 120, 120, 120, 400],
  };

  String get label => switch (this) {
    Signal.tap => 'Dokunuş',
    Signal.ruku => 'Rükû (1 kısa)',
    Signal.secde => 'Secde (2 kısa)',
    Signal.transition => 'Oturma / kalkma (1 uzun)',
    Signal.done => 'Namaz bitti (3 uzun)',
    Signal.zikrGoal => 'Zikir hedefi tamam',
  };

  /// Desendeki titreşim (açık) sayısı.
  int get pulseCount {
    var n = 0;
    for (var i = 1; i < pattern.length; i += 2) {
      if (pattern[i] > 0) n++;
    }
    return n;
  }
}
