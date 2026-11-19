import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/settings.dart';
import 'package:namaz_asistani/core/vibration_patterns.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Varsayılanlar yaşlı dostu', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    expect(s.onboardingDone, isFalse);
    expect(s.largeText, isTrue);
    expect(s.readingSpeed, ReadingSpeed.slow);
    expect(s.keepAudioScreenOff, isTrue);
    expect(s.vibrationOn, isTrue);
    expect(s.cityName, isNull, reason: 'konum zorunlu değil');
  });

  test('İlk kurulum ve ayarlar saklanır', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    await s.completeOnboarding(
      madhab: Madhab.safii,
      surahs: ['Nas', 'İhlas'],
      speed: ReadingSpeed.fast,
    );
    await s.setCity('İzmir');
    await s.setThemeMode(ThemeMode.dark);
    await s.setLargeText(false);

    final s2 = await AppSettings.load();
    expect(s2.onboardingDone, isTrue);
    expect(s2.madhab, Madhab.safii);
    expect(s2.knownSurahs, [
      'Fatiha',
      'İhlas',
      'Nas',
    ], reason: 'Fatiha her zaman eklenir, sıra sabit');
    expect(s2.readingSpeed, ReadingSpeed.fast);
    expect(s2.cityName, 'İzmir');
    expect(s2.themeMode, ThemeMode.dark);
    expect(s2.largeText, isFalse);
  });

  test('Titreşim dili eşlemesi', () {
    expect(Signal.ruku.pulseCount, 1);
    expect(Signal.secde.pulseCount, 2);
    expect(Signal.transition.pulseCount, 1);
    expect(Signal.done.pulseCount, 3);
    // Kısa / uzun ayrımı
    expect(Signal.ruku.pattern[1], lessThan(Signal.transition.pattern[1]));
    expect(Signal.done.pattern.where((x) => x == kLong).length, 3);
    expect(Signal.secde.pattern.skip(1).where((x) => x == kShort).length, 2);
  });
}
