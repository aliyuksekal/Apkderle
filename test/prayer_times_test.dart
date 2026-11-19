import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/cities.dart';
import 'package:namaz_asistani/core/prayer_times.dart';

int _min(DateTime t) => t.hour * 60 + t.minute;

void main() {
  group('Namaz vakti hesaplama', () {
    // Diyanet takvimi, 19.08.2026 (gazetevatan.com'daki Diyanet tablosu).
    final refs = <String, (double, double, List<int>)>{
      'Bandırma': (40.35, 27.97, [4, 42, 6, 16, 13, 17, 17, 4, 20, 8, 21, 36]),
      'Nazilli': (37.91, 28.32, [4, 49, 6, 18, 13, 15, 17, 0, 20, 3, 21, 26]),
    };
    refs.forEach((name, r) {
      test('$name Diyanet takvimine ±2 dakika yakın', () {
        final pt = PrayerTimes.calculate(
          latitude: r.$1,
          longitude: r.$2,
          date: DateTime.utc(2026, 8, 19),
          utcOffset: kTurkeyOffset,
        );
        for (var i = 0; i < 6; i++) {
          final p = PrayerName.values[i];
          final expected = r.$3[2 * i] * 60 + r.$3[2 * i + 1];
          expect(
            (_min(pt[p]) - expected).abs(),
            lessThanOrEqualTo(2),
            reason: '${p.label}: ${hhmm(pt[p])}',
          );
        }
      });
    });

    test('81 ilin tamamında vakitler doğru sırada', () {
      expect(kCities.length, 81);
      for (final c in kCities) {
        for (final d in [
          DateTime.utc(2026, 1, 15),
          DateTime.utc(2026, 6, 21),
        ]) {
          final pt = PrayerTimes.calculate(
            latitude: c.lat,
            longitude: c.lng,
            date: d,
            utcOffset: kTurkeyOffset,
          );
          for (var i = 1; i < 6; i++) {
            expect(
              pt[PrayerName.values[i]].isAfter(pt[PrayerName.values[i - 1]]),
              isTrue,
              reason: '${c.name} $d',
            );
          }
        }
      }
    });

    test('Güneş namaz vakti sayılmaz, sıradaki vakit atlanır', () {
      final c = cityByName('İzmir')!;
      final today = PrayerTimes.calculate(
        latitude: c.lat,
        longitude: c.lng,
        date: DateTime.utc(2026, 11, 19),
        utcOffset: kTurkeyOffset,
      );
      final tomorrow = PrayerTimes.calculate(
        latitude: c.lat,
        longitude: c.lng,
        date: DateTime.utc(2026, 11, 20),
        utcOffset: kTurkeyOffset,
      );
      // İmsak ile güneş arası: sıradaki öğle olmalı.
      final now = today[PrayerName.imsak].add(const Duration(minutes: 5));
      final next = findNextPrayer(
        today: today,
        tomorrow: tomorrow,
        nowLocal: now,
      );
      expect(next.name, PrayerName.ogle);
      // Yatsıdan sonra: yarının imsakı.
      final late = today[PrayerName.yatsi].add(const Duration(minutes: 1));
      final n2 = findNextPrayer(
        today: today,
        tomorrow: tomorrow,
        nowLocal: late,
      );
      expect(n2.name, PrayerName.imsak);
      expect(n2.time.day, 20);
    });

    test('Kalan süre biçimi', () {
      expect(
        formatRemaining(const Duration(hours: 1, minutes: 12)),
        '1 sa 12 dk',
      );
      expect(
        formatRemaining(const Duration(minutes: 12, seconds: 10)),
        '13 dk',
      );
      expect(formatRemaining(const Duration(hours: 2)), '2 sa');
      expect(formatRemaining(Duration.zero), "1 dk'dan az");
    });
  });

  group('Kıble', () {
    test('İstanbul kıble açısı ≈ 151.6°', () {
      final c = cityByName('İstanbul')!;
      expect(qiblaBearing(c.lat, c.lng), closeTo(151.6, 0.5));
    });
    test('Türkiye\'nin her yerinde kıble güneydoğu-güney arası', () {
      for (final c in kCities) {
        final q = qiblaBearing(c.lat, c.lng);
        expect(q, inInclusiveRange(130, 200), reason: c.name);
      }
    });
    test('Şehir arama Türkçe harflere duyarlı', () {
      expect(searchCities('izmir').single.name, 'İzmir');
      expect(searchCities('IĞDIR').single.name, 'Iğdır');
      expect(searchCities('şanlı').single.name, 'Şanlıurfa');
    });
  });
}
