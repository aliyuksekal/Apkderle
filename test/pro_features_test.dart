import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/cities.dart';
import 'package:namaz_asistani/core/family.dart';
import 'package:namaz_asistani/core/place.dart';
import 'package:namaz_asistani/core/prayer_log.dart';
import 'package:namaz_asistani/core/prayer_times.dart';
import 'package:namaz_asistani/core/reminders.dart';
import 'package:namaz_asistani/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

final izmir = Place('İzmir', 38.42, 27.14, kTurkeyOffset);

/// İzmir yerel saatini gerçek UTC'ye çevirir.
DateTime localToUtc(int y, int m, int d, int h, [int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(kTurkeyOffset);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Kaza namazı otomatik sayacı', () {
    test('İşaretlenmeyen ve süresi çıkan vakitler kazaya yazılır', () async {
      final log = PrayerLog(await SharedPreferences.getInstance());
      // Takip 19 Kasım 09:00'da başlar (sabah vakti çoktan çıkmış).
      await log.processMissed(
        place: izmir,
        madhab: Madhab.hanefi,
        nowUtc: localToUtc(2026, 11, 19, 9),
      );
      expect(log.kazaTotal, 0);
      // Öğleyi kıldı.
      await log.setMarked('2026-11-19', Farz.ogle, true);
      // Ertesi gün 10:00: ikindi, akşam, yatsı (+vitir) ve 20 Kasım sabahı kaçtı.
      final added = await log.processMissed(
        place: izmir,
        madhab: Madhab.hanefi,
        nowUtc: localToUtc(2026, 11, 20, 10),
      );
      expect(added, 4);
      expect(log.kaza['ogle'], 0);
      expect(log.kaza['ikindi'], 1);
      expect(log.kaza['yatsi'], 1);
      expect(log.kaza['vitir'], 1, reason: 'Hanefi: yatsıyla vitir');
      expect(log.kaza['sabah'], 1, reason: '20 Kasım sabahı');
      // Aynı ana tekrar işlem yapmak ikinci kez saymaz.
      expect(
        await log.processMissed(
          place: izmir,
          madhab: Madhab.hanefi,
          nowUtc: localToUtc(2026, 11, 20, 10),
        ),
        0,
      );
    });

    test('Sonradan "kıldım" denirse kazadan düşer', () async {
      final log = PrayerLog(await SharedPreferences.getInstance());
      await log.processMissed(
        place: izmir,
        madhab: Madhab.safii,
        nowUtc: localToUtc(2026, 11, 19, 9),
      );
      await log.processMissed(
        place: izmir,
        madhab: Madhab.safii,
        nowUtc: localToUtc(2026, 11, 19, 23),
      );
      expect(log.kaza['ogle'], 1);
      expect(log.kaza['vitir'], 0, reason: 'Şafi: vitir sayılmaz');
      await log.setMarked('2026-11-19', Farz.ogle, true);
      expect(log.kaza['ogle'], 0);
    });

    test('Pro kapalıyken sayılmaz; geçmiş borç ve kaza kılma', () async {
      final log = PrayerLog(await SharedPreferences.getInstance());
      await log.processMissed(
        place: izmir,
        madhab: Madhab.hanefi,
        count: false,
        nowUtc: localToUtc(2026, 11, 19, 9),
      );
      await log.processMissed(
        place: izmir,
        madhab: Madhab.hanefi,
        count: false,
        nowUtc: localToUtc(2026, 11, 21, 9),
      );
      expect(log.kazaTotal, 0);
      await log.addDebtDays(365, includeVitir: true);
      expect(log.kaza['sabah'], 365);
      expect(log.kaza['vitir'], 365);
      await log.payOne('sabah');
      expect(log.kaza['sabah'], 364);
      // Kalıcı
      final again = PrayerLog(await SharedPreferences.getInstance());
      expect(again.kaza['sabah'], 364);
    });
  });

  group('Namaz + ilaç hatırlatma', () {
    test('Seçili vakitler ve ilaç saatleri planlanır', () async {
      final r = ReminderSettings(await SharedPreferences.getInstance())
        ..prayerOn = true
        ..prayers = {PrayerName.ogle, PrayerName.aksam}
        ..medicines = [
          Medicine(id: 'a', name: 'Tansiyon ilacı', times: ['09:00']),
        ];
      final now = localToUtc(2026, 11, 19, 8);
      final plan = planNotifications(r: r, place: izmir, nowUtc: now, days: 2);
      final vakit = plan.where((n) => n.channel == 'vakit').toList();
      expect(vakit.length, 4); // 2 gün x 2 vakit
      final t = PrayerTimes.calculate(
        latitude: izmir.lat,
        longitude: izmir.lng,
        date: DateTime.utc(2026, 11, 19),
        utcOffset: kTurkeyOffset,
      );
      expect(vakit.first.atUtc, t[PrayerName.ogle].subtract(kTurkeyOffset));
      expect(vakit.first.title, 'Öğle vakti girdi');
      final ilac = plan.where((n) => n.channel == 'ilac').toList();
      expect(ilac.length, 2);
      expect(ilac.first.body, contains('Tansiyon ilacı'));
      expect(
        plan.map((n) => n.id).toSet().length,
        plan.length,
        reason: 'bildirim kimlikleri çakışmamalı',
      );
      expect(plan.every((n) => n.atUtc.isAfter(now)), isTrue);
    });

    test('Kapalıyken vakit bildirimi yok', () async {
      final r = ReminderSettings(await SharedPreferences.getInstance());
      expect(
        planNotifications(r: r, place: izmir, nowUtc: DateTime.utc(2026)),
        isEmpty,
      );
    });
  });

  group('Aile takibi', () {
    test('Paylaşım kodu okunaklı ve tahmin edilmesi zor', () {
      final codes = {for (var i = 0; i < 200; i++) newShareCode(Random(i))};
      expect(codes.length, 200);
      for (final c in codes) {
        expect(c, matches(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$')));
      }
      expect(prettyCode('K7M2QX9P'), 'K7M2-QX9P');
      expect(normalizeCode(' k7m2-qx9p '), 'K7M2QX9P');
      expect(newSecret().length, 32);
    });

    test('Özet metni', () {
      final now = DateTime(2026, 11, 20, 15);
      final s = FamilyStatus('Annem', {
        '2026-11-20': {'sabah', 'ogle'},
      }, now);
      expect(familySummary(s, now), 'Bugün Sabah, Öğle kılındı');
      final all = FamilyStatus('Annem', {
        '2026-11-20': {'sabah', 'ogle', 'ikindi', 'aksam', 'yatsi'},
      }, now);
      expect(familySummary(all, now), 'Bugün 5 vaktin hepsini kıldı');
    });
  });
}
