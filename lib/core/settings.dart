import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Madhab { hanefi, safii }

enum ReadingSpeed { slow, normal, fast }

enum ZikrAnnounce { everyTap, everyTen, off }

extension MadhabLabel on Madhab {
  String get label => this == Madhab.hanefi ? 'Hanefi' : 'Şafi';
}

extension ReadingSpeedX on ReadingSpeed {
  String get label => switch (this) {
    ReadingSpeed.slow => 'Yavaş',
    ReadingSpeed.normal => 'Normal',
    ReadingSpeed.fast => 'Hızlı',
  };

  /// Süre çarpanı: yalnızca duraklama/tempo değişir, tilavet telaffuzu değişmez.
  double get factor => switch (this) {
    ReadingSpeed.slow => 1.0,
    ReadingSpeed.normal => 0.8,
    ReadingSpeed.fast => 0.65,
  };
}

/// Kullanıcının seçebileceği sureler (yalnızca adlar; metin/ses içerik
/// dosyalarında, doğrulanarak eklenir).
const List<String> kSelectableSurahs = [
  'Fatiha',
  'İhlas',
  'Kevser',
  'Nas',
  'Felak',
  'Asr',
  'Fil',
  'Kureyş',
  'Maun',
  'Kâfirun',
  'Nasr',
  'Tebbet',
];

/// Uygulama ayarları. Hepsi cihazda (SharedPreferences) saklanır.
class AppSettings extends ChangeNotifier {
  AppSettings(this._p);

  final SharedPreferences _p;

  static Future<AppSettings> load() async =>
      AppSettings(await SharedPreferences.getInstance());

  // --- Anahtarlar
  static const _kOnboarding = 'onboarding_done';
  static const _kMadhab = 'madhab';
  static const _kSurahs = 'known_surahs';
  static const _kSpeed = 'reading_speed';
  static const _kCity = 'city_name';
  static const _kGpsLat = 'gps_lat';
  static const _kGpsLng = 'gps_lng';
  static const _kLargeText = 'large_text';
  static const _kVibration = 'vibration';
  static const _kSound = 'sound_feedback';
  static const _kKeepAudio = 'keep_audio_screen_off';
  static const _kTheme = 'theme_mode';
  static const _kAnnounce = 'zikr_announce';

  bool get onboardingDone => _p.getBool(_kOnboarding) ?? false;
  Madhab get madhab =>
      Madhab.values.asNameMap()[_p.getString(_kMadhab)] ?? Madhab.hanefi;
  List<String> get knownSurahs =>
      _p.getStringList(_kSurahs) ?? const ['Fatiha', 'İhlas'];
  ReadingSpeed get readingSpeed =>
      ReadingSpeed.values.asNameMap()[_p.getString(_kSpeed)] ??
      ReadingSpeed.slow;

  /// Seçili il adı (liste) ya da 'GPS'. null = henüz seçilmedi.
  String? get cityName => _p.getString(_kCity);
  double? get gpsLat => _p.getDouble(_kGpsLat);
  double? get gpsLng => _p.getDouble(_kGpsLng);

  bool get largeText => _p.getBool(_kLargeText) ?? true;
  bool get vibrationOn => _p.getBool(_kVibration) ?? true;
  bool get soundFeedback => _p.getBool(_kSound) ?? true;
  bool get keepAudioScreenOff => _p.getBool(_kKeepAudio) ?? true;
  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_p.getString(_kTheme)] ?? ThemeMode.system;
  ZikrAnnounce get zikrAnnounce =>
      ZikrAnnounce.values.asNameMap()[_p.getString(_kAnnounce)] ??
      ZikrAnnounce.everyTen;

  Future<void> _set(Future<bool> f) async {
    await f;
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required Madhab madhab,
    required List<String> surahs,
    required ReadingSpeed speed,
  }) async {
    await _p.setString(_kMadhab, madhab.name);
    await _p.setStringList(_kSurahs, _normalizeSurahs(surahs));
    await _p.setString(_kSpeed, speed.name);
    await _set(_p.setBool(_kOnboarding, true));
  }

  Future<void> skipOnboarding() => _set(_p.setBool(_kOnboarding, true));

  Future<void> setMadhab(Madhab m) => _set(_p.setString(_kMadhab, m.name));
  Future<void> setKnownSurahs(List<String> s) =>
      _set(_p.setStringList(_kSurahs, _normalizeSurahs(s)));
  Future<void> setReadingSpeed(ReadingSpeed s) =>
      _set(_p.setString(_kSpeed, s.name));
  Future<void> setCity(String name) => _set(_p.setString(_kCity, name));
  Future<void> setGps(double lat, double lng) async {
    await _p.setDouble(_kGpsLat, lat);
    await _p.setDouble(_kGpsLng, lng);
    await _set(_p.setString(_kCity, 'GPS'));
  }

  Future<void> setLargeText(bool v) => _set(_p.setBool(_kLargeText, v));
  Future<void> setVibration(bool v) => _set(_p.setBool(_kVibration, v));
  Future<void> setSoundFeedback(bool v) => _set(_p.setBool(_kSound, v));
  Future<void> setKeepAudioScreenOff(bool v) =>
      _set(_p.setBool(_kKeepAudio, v));
  Future<void> setThemeMode(ThemeMode m) => _set(_p.setString(_kTheme, m.name));
  Future<void> setZikrAnnounce(ZikrAnnounce a) =>
      _set(_p.setString(_kAnnounce, a.name));

  /// Fatiha her namazda okunduğu için listeden çıkarılamaz; sıralama sabit.
  static List<String> _normalizeSurahs(List<String> s) {
    final set = {...s, 'Fatiha'};
    return kSelectableSurahs.where(set.contains).toList();
  }
}
