import 'dart:math' as math;

/// Namaz vakitleri — cihazda, internetsiz astronomik hesaplama.
///
/// Yöntem: Diyanet İşleri Başkanlığı'nın kullandığı açılar
/// (İmsak −18°, Yatsı −17°, İkindi gölge boyu 1 kat / asr-ı evvel) ve yaygın
/// kullanılan Diyanet temkin düzeltmeleri (Güneş −7, Öğle +5, İkindi +4,
/// Akşam +7 dakika). Diyanet'in resmî takvimiyle 1–2 dakika fark olabilir;
/// bu nedenle arayüzde yöntem açıkça yazılır.
enum PrayerName { imsak, gunes, ogle, ikindi, aksam, yatsi }

extension PrayerNameX on PrayerName {
  String get label => switch (this) {
    PrayerName.imsak => 'İmsak',
    PrayerName.gunes => 'Güneş',
    PrayerName.ogle => 'Öğle',
    PrayerName.ikindi => 'İkindi',
    PrayerName.aksam => 'Akşam',
    PrayerName.yatsi => 'Yatsı',
  };

  /// "İkindi'ye", "Öğle'ye" gibi yönelme hâli.
  String get dative => switch (this) {
    PrayerName.imsak => "İmsak'a",
    PrayerName.gunes => "Güneş'e",
    PrayerName.ogle => "Öğle'ye",
    PrayerName.ikindi => "İkindi'ye",
    PrayerName.aksam => "Akşam'a",
    PrayerName.yatsi => "Yatsı'ya",
  };

  /// Güneş doğuşu namaz vakti değildir.
  bool get isPrayer => this != PrayerName.gunes;
}

const String kMethodDescription =
    'Hesaplama: Diyanet açıları (İmsak 18°, Yatsı 17°, İkindi asr-ı evvel) '
    've Diyanet temkin düzeltmeleri. Cihazda hesaplanır; resmî Diyanet '
    'takviminden 1–2 dakika farklı olabilir.';

class PrayerTimes {
  PrayerTimes._(this.date, this.times, [this.rawMinutes = const {}]);

  /// Yuvarlamadan önceki dakika değerleri (test/ayar için).
  final Map<PrayerName, double> rawMinutes;

  final DateTime date;

  /// Yerel saat (utcOffset uygulanmış), ama DateTime.utc nesnesi olarak
  /// tutulur ki cihaz saat dilimi karışmasın.
  final Map<PrayerName, DateTime> times;

  DateTime operator [](PrayerName p) => times[p]!;

  /// [date] yalnızca yıl/ay/gün için kullanılır.
  /// [utcOffset] o konumun yerel saat farkı (Türkiye: +3 saat, sabit).
  factory PrayerTimes.calculate({
    required double latitude,
    required double longitude,
    required DateTime date,
    required Duration utcOffset,
  }) {
    final calc = _Calc(latitude, longitude, date);
    final raw = calc.compute(); // UTC saat olarak (ondalıklı)
    const temkin = {
      PrayerName.imsak: 0,
      PrayerName.gunes: -7,
      PrayerName.ogle: 5,
      PrayerName.ikindi: 4,
      PrayerName.aksam: 7,
      PrayerName.yatsi: 0,
    };
    final base = DateTime.utc(date.year, date.month, date.day);
    final out = <PrayerName, DateTime>{};
    final rawMin = <PrayerName, double>{};
    for (final p in PrayerName.values) {
      final minutes = raw[p]! * 60 + temkin[p]! + utcOffset.inMinutes;
      rawMin[p] = minutes;
      // Saniyeleri yuvarla (Diyanet dakikaya yuvarlar).
      out[p] = base.add(Duration(minutes: minutes.round()));
    }
    return PrayerTimes._(date, out, rawMin);
  }
}

/// Şu anki ve sıradaki namaz (Güneş hariç).
class NextPrayer {
  NextPrayer(this.name, this.time, this.remaining);
  final PrayerName name;
  final DateTime time;
  final Duration remaining;
}

/// [nowLocal]: konumun yerel saatinde "şimdi" (DateTime.utc olarak temsil).
NextPrayer findNextPrayer({
  required PrayerTimes today,
  required PrayerTimes tomorrow,
  required DateTime nowLocal,
}) {
  for (final p in PrayerName.values.where((p) => p.isPrayer)) {
    if (today[p].isAfter(nowLocal)) {
      return NextPrayer(p, today[p], today[p].difference(nowLocal));
    }
  }
  final t = tomorrow[PrayerName.imsak];
  return NextPrayer(PrayerName.imsak, t, t.difference(nowLocal));
}

/// "1 sa 12 dk" / "12 dk" / "1 dk'dan az"
String formatRemaining(Duration d) {
  final totalMin = (d.inSeconds / 60).ceil();
  if (totalMin <= 0) return "1 dk'dan az";
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (h == 0) return '$m dk';
  if (m == 0) return '$h sa';
  return '$h sa $m dk';
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Astronomik hesaplama (praytimes.org algoritması temel alınmıştır).

class _Calc {
  _Calc(this.lat, this.lng, DateTime d)
    : jDate = _julian(d.year, d.month, d.day) - lng / (15 * 24);

  final double lat;
  final double lng;
  final double jDate;

  static double _julian(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static double _dsin(double d) => math.sin(d * math.pi / 180);
  static double _dcos(double d) => math.cos(d * math.pi / 180);
  static double _dtan(double d) => math.tan(d * math.pi / 180);
  static double _darcsin(double x) => math.asin(x) * 180 / math.pi;
  static double _darccos(double x) => math.acos(x) * 180 / math.pi;
  static double _darctan2(double y, double x) =>
      math.atan2(y, x) * 180 / math.pi;
  static double _darccot(double x) => math.atan(1 / x) * 180 / math.pi;
  static double _fix(double a, double b) {
    a = a - b * (a / b).floor();
    return a < 0 ? a + b : a;
  }

  ({double decl, double eqt}) _sun(double jd) {
    final d = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * _dsin(g) + 0.020 * _dsin(2 * g), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _fix(_darctan2(_dcos(e) * _dsin(l), _dcos(l)) / 15, 24);
    final eqt = q / 15 - ra;
    final decl = _darcsin(_dsin(e) * _dsin(l));
    return (decl: decl, eqt: eqt);
  }

  double _midDay(double t) {
    final eqt = _sun(jDate + t).eqt;
    return _fix(12 - eqt, 24);
  }

  double _sunAngleTime(double angle, double t, {bool ccw = false}) {
    final decl = _sun(jDate + t).decl;
    final noon = _midDay(t);
    final cosVal =
        (-_dsin(angle) - _dsin(decl) * _dsin(lat)) / (_dcos(decl) * _dcos(lat));
    final tt = _darccos(cosVal.clamp(-1.0, 1.0)) / 15;
    return noon + (ccw ? -tt : tt);
  }

  double _asr(double factor, double t) {
    final decl = _sun(jDate + t).decl;
    final angle = -_darccot(factor + _dtan((lat - decl).abs()));
    return _sunAngleTime(angle, t);
  }

  /// Saatleri UTC (ondalıklı saat) olarak döndürür.
  Map<PrayerName, double> compute() {
    // İlk tahminler, gün kesri olarak.
    var t = {
      PrayerName.imsak: 5.0,
      PrayerName.gunes: 6.0,
      PrayerName.ogle: 12.0,
      PrayerName.ikindi: 13.0,
      PrayerName.aksam: 18.0,
      PrayerName.yatsi: 18.0,
    };
    for (var i = 0; i < 2; i++) {
      double f(PrayerName p) => t[p]! / 24;
      t = {
        PrayerName.imsak: _sunAngleTime(18, f(PrayerName.imsak), ccw: true),
        PrayerName.gunes: _sunAngleTime(0.833, f(PrayerName.gunes), ccw: true),
        PrayerName.ogle: _midDay(f(PrayerName.ogle)),
        PrayerName.ikindi: _asr(1, f(PrayerName.ikindi)),
        PrayerName.aksam: _sunAngleTime(0.833, f(PrayerName.aksam)),
        PrayerName.yatsi: _sunAngleTime(17, f(PrayerName.yatsi)),
      };
    }
    return t.map((k, v) => MapEntry(k, v - lng / 15));
  }
}
