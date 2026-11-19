import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> kZikrNames = [
  'Sübhanallah',
  'Elhamdülillah',
  'Allahu Ekber',
  'Lâ ilâhe illallah',
  'Estağfirullah',
  'Salavat',
];

const List<int> kZikrTargets = [33, 99, 100];

/// Zikirmatik durumu. Saf mantık + yerel saklama.
/// Günlük toplamlar tarih anahtarıyla (yyyy-MM-dd) tutulur, son 60 gün saklanır.
class ZikrCounter extends ChangeNotifier {
  ZikrCounter(this._p, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _load();
  }

  final SharedPreferences _p;
  final DateTime Function() _clock;

  static const _kState = 'zikr_state_v1';

  String name = kZikrNames.first;
  int count = 0;
  int target = 33;
  Map<String, int> history = {};

  /// Son eklemede hedefe ulaşıldı mı? (Arayüz "Maşallah!" gösterir.)
  bool justCompleted = false;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get todayTotal => history[dayKey(_clock())] ?? 0;
  bool get goalReached => count >= target;
  double get progress => target <= 0 ? 0 : (count / target).clamp(0.0, 1.0);

  void _load() {
    final raw = _p.getString(_kState);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      name = m['name'] as String? ?? name;
      count = m['count'] as int? ?? 0;
      target = m['target'] as int? ?? 33;
      history = (m['history'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v as int),
      );
    } catch (_) {
      // Bozuk kayıt: sıfırdan başla.
    }
  }

  Future<void> _save() async {
    final keys = history.keys.toList()..sort();
    while (keys.length > 60) {
      history.remove(keys.removeAt(0));
    }
    await _p.setString(
      _kState,
      jsonEncode({
        'name': name,
        'count': count,
        'target': target,
        'history': history,
      }),
    );
  }

  /// +1. Hedefe tam bu dokunuşta ulaşıldıysa true döner.
  Future<bool> increment() async {
    count++;
    final k = dayKey(_clock());
    history[k] = (history[k] ?? 0) + 1;
    justCompleted = count == target;
    await _save();
    notifyListeners();
    return justCompleted;
  }

  /// Son dokunuşu geri al (günlük toplamdan da düşer).
  Future<void> undo() async {
    if (count == 0) return;
    count--;
    final k = dayKey(_clock());
    final v = history[k] ?? 0;
    if (v > 0) history[k] = v - 1;
    justCompleted = false;
    await _save();
    notifyListeners();
  }

  /// Sayaç sıfırlanır; günlük toplam korunur.
  Future<void> reset() async {
    count = 0;
    justCompleted = false;
    await _save();
    notifyListeners();
  }

  Future<void> setZikr(String n) async {
    if (n == name) return;
    name = n;
    count = 0;
    justCompleted = false;
    await _save();
    notifyListeners();
  }

  Future<void> setTarget(int t) async {
    if (t < 1) return;
    target = t;
    justCompleted = false;
    await _save();
    notifyListeners();
  }

  /// Son [days] günün toplamları (eskiden yeniye).
  List<MapEntry<String, int>> lastDays(int days) {
    final now = _clock();
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final k = dayKey(DateTime(now.year, now.month, now.day - i));
          return MapEntry(k, history[k] ?? 0);
        }(),
    ];
  }
}

/// "1240" → "1.240"
String trThousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
