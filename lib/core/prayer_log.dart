import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'place.dart';
import 'prayer_times.dart';
import 'settings.dart';
import 'zikr.dart' show ZikrCounter;

/// Beş vakit farz (kaza takibi anahtarları).
enum Farz { sabah, ogle, ikindi, aksam, yatsi }

extension FarzX on Farz {
  String get label => switch (this) {
    Farz.sabah => 'Sabah',
    Farz.ogle => 'Öğle',
    Farz.ikindi => 'İkindi',
    Farz.aksam => 'Akşam',
    Farz.yatsi => 'Yatsı',
  };

  /// Vaktin başladığı an.
  PrayerName get start => switch (this) {
    Farz.sabah => PrayerName.imsak,
    Farz.ogle => PrayerName.ogle,
    Farz.ikindi => PrayerName.ikindi,
    Farz.aksam => PrayerName.aksam,
    Farz.yatsi => PrayerName.yatsi,
  };
}

/// Kaza sayaçlarının anahtarları: 5 farz + vitir (Hanefi'de vacip).
const List<String> kKazaKeys = [
  'sabah',
  'ogle',
  'ikindi',
  'aksam',
  'yatsi',
  'vitir',
];

String kazaLabel(String k) =>
    k == 'vitir' ? 'Vitir' : Farz.values.byName(k).label;

/// Günlük "kıldım" işaretleri ve kaza namazı sayacı. Her şey cihazda.
///
/// Otomatik kaza: bir vaktin süresi çıktığında (sonraki vakit girdiğinde)
/// o gün için "kıldım" işaretlenmemişse kaza sayacı 1 artar. Takip,
/// özelliğin açıldığı andan sonraki vakitler için yapılır; geçmişe dönük
/// sayım yapılmaz.
class PrayerLog extends ChangeNotifier {
  PrayerLog(this._p, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _load();
  }

  final SharedPreferences _p;
  final DateTime Function() _clock;
  static const _kState = 'prayer_log_v1';

  /// gün (yyyy-MM-dd) → kılınan vakitler
  Map<String, Set<String>> marks = {};

  /// Kaza borcu sayaçları.
  Map<String, int> kaza = {for (final k in kKazaKeys) k: 0};

  /// Otomatik sayılan (gün|vakit) kayıtları — sonradan "kıldım" denirse geri
  /// alınabilsin diye.
  Set<String> autoCounted = {};

  /// Konum saatine göre (DateTime.utc temsili) milisaniye.
  int? trackStartMs;
  int? lastProcessedMs;

  /// Çağrıldığında değişiklik dinleyicisi (aile paylaşımı için).
  void Function()? onMarksChanged;

  int get kazaTotal => kaza.values.fold(0, (a, b) => a + b);

  void _load() {
    final raw = _p.getString(_kState);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      marks = (m['marks'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as List).cast<String>().toSet()),
      );
      final kz = (m['kaza'] as Map<String, dynamic>? ?? {});
      for (final k in kKazaKeys) {
        kaza[k] = kz[k] as int? ?? 0;
      }
      autoCounted = ((m['auto'] as List?) ?? const []).cast<String>().toSet();
      trackStartMs = m['trackStart'] as int?;
      lastProcessedMs = m['lastProcessed'] as int?;
    } catch (_) {}
  }

  Future<void> _save() async {
    final keys = marks.keys.toList()..sort();
    while (keys.length > 120) {
      marks.remove(keys.removeAt(0));
    }
    // Eski otomatik kayıtları da buda.
    if (keys.isNotEmpty) {
      final oldest = keys.first;
      autoCounted.removeWhere((e) => e.split('|').first.compareTo(oldest) < 0);
    }
    await _p.setString(
      _kState,
      jsonEncode({
        'marks': marks.map((k, v) => MapEntry(k, v.toList())),
        'kaza': kaza,
        'auto': autoCounted.toList(),
        'trackStart': trackStartMs,
        'lastProcessed': lastProcessedMs,
      }),
    );
  }

  static String dayKey(DateTime d) => ZikrCounter.dayKey(d);

  bool isMarked(String day, Farz f) => marks[day]?.contains(f.name) ?? false;

  Set<String> marksFor(String day) => marks[day] ?? const {};

  /// "Kıldım" işaretini aç/kapat. Otomatik kazaya yazılmış bir vakit sonradan
  /// işaretlenirse (işaretlemeyi unutmuş) kaza sayacından düşülür.
  Future<void> setMarked(String day, Farz f, bool value) async {
    final set = marks.putIfAbsent(day, () => <String>{});
    if (value) {
      set.add(f.name);
      if (autoCounted.remove('$day|${f.name}')) {
        kaza[f.name] = (kaza[f.name]! - 1).clamp(0, 1 << 30);
        if (autoCounted.remove('$day|vitir')) {
          kaza['vitir'] = (kaza['vitir']! - 1).clamp(0, 1 << 30);
        }
      }
    } else {
      set.remove(f.name);
    }
    await _save();
    notifyListeners();
    onMarksChanged?.call();
  }

  /// Bu an itibarıyla işaretlenmemiş, süresi çıkmış vakitleri kazaya yazar.
  /// [count] false ise yalnızca işlem noktası ilerletilir (özellik kapalıyken).
  Future<int> processMissed({
    required Place place,
    required Madhab madhab,
    bool count = true,
    DateTime? nowUtc,
  }) async {
    final now = place.nowLocal(nowUtc ?? _clock().toUtc());
    final nowMs = now.millisecondsSinceEpoch;
    if (trackStartMs == null || lastProcessedMs == null || !count) {
      // İlk kez (ya da sayım kapalı): bundan sonrasını takip et.
      if (count) trackStartMs ??= nowMs;
      lastProcessedMs = nowMs;
      if (!count) trackStartMs = null;
      await _save();
      return 0;
    }
    final last = DateTime.fromMillisecondsSinceEpoch(
      lastProcessedMs!,
      isUtc: true,
    );
    if (!now.isAfter(last)) return 0;
    var added = 0;
    // En fazla 60 gün geriye bak (uzun süre açılmazsa).
    var day = DateTime.utc(
      last.year,
      last.month,
      last.day,
    ).subtract(const Duration(days: 1));
    final limit = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 60));
    if (day.isBefore(limit)) day = limit;
    while (!day.isAfter(now)) {
      final t = PrayerTimes.calculate(
        latitude: place.lat,
        longitude: place.lng,
        date: day,
        utcOffset: place.utcOffset,
      );
      final next = PrayerTimes.calculate(
        latitude: place.lat,
        longitude: place.lng,
        date: day.add(const Duration(days: 1)),
        utcOffset: place.utcOffset,
      );
      final key = dayKey(day);
      for (final f in Farz.values) {
        final start = t[f.start];
        final end = switch (f) {
          Farz.sabah => t[PrayerName.gunes],
          Farz.ogle => t[PrayerName.ikindi],
          Farz.ikindi => t[PrayerName.aksam],
          Farz.aksam => t[PrayerName.yatsi],
          Farz.yatsi => next[PrayerName.imsak],
        };
        if (start.millisecondsSinceEpoch < trackStartMs!) continue;
        if (!end.isAfter(last) || end.isAfter(now)) continue;
        if (isMarked(key, f)) continue;
        if (autoCounted.contains('$key|${f.name}')) continue;
        kaza[f.name] = kaza[f.name]! + 1;
        autoCounted.add('$key|${f.name}');
        added++;
        if (f == Farz.yatsi && madhab == Madhab.hanefi) {
          kaza['vitir'] = kaza['vitir']! + 1;
          autoCounted.add('$key|vitir');
        }
      }
      day = day.add(const Duration(days: 1));
    }
    lastProcessedMs = nowMs;
    await _save();
    if (added > 0) notifyListeners();
    return added;
  }

  /// Geçmiş yıllar için toplu borç ekle (ör. "5 yıl kılmadım").
  Future<void> addDebtDays(int days, {required bool includeVitir}) async {
    if (days <= 0) return;
    for (final f in Farz.values) {
      kaza[f.name] = kaza[f.name]! + days;
    }
    if (includeVitir) kaza['vitir'] = kaza['vitir']! + days;
    await _save();
    notifyListeners();
  }

  /// Bir kaza kılındı: sayaçtan 1 düş.
  Future<void> payOne(String key) async {
    if ((kaza[key] ?? 0) <= 0) return;
    kaza[key] = kaza[key]! - 1;
    await _save();
    notifyListeners();
  }

  Future<void> addOne(String key) async {
    kaza[key] = (kaza[key] ?? 0) + 1;
    await _save();
    notifyListeners();
  }

  Future<void> resetKaza() async {
    for (final k in kKazaKeys) {
      kaza[k] = 0;
    }
    autoCounted.clear();
    await _save();
    notifyListeners();
  }
}
