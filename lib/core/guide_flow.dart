import 'dart:convert';

import 'package:flutter/services.dart';

import 'settings.dart';
import 'vibration_patterns.dart';

/// Rehberde seçilebilen namazlar.
class PrayerOption {
  const PrayerOption(this.id, this.title, this.rakats, {this.isFard = true});
  final String id;
  final String title;
  final int rakats;
  final bool isFard;

  String get label => '$title — $rakats rekât';
}

const List<PrayerOption> kPrayerOptions = [
  PrayerOption('sabah_sunnet', 'Sabah Sünneti', 2, isFard: false),
  PrayerOption('sabah_farz', 'Sabah Farzı', 2),
  PrayerOption('ogle_farz', 'Öğle Farzı', 4),
  PrayerOption('ikindi_farz', 'İkindi Farzı', 4),
  PrayerOption('aksam_farz', 'Akşam Farzı', 3),
  PrayerOption('yatsi_farz', 'Yatsı Farzı', 4),
  PrayerOption('iki_rekat_sunnet', '2 Rekâtlık Sünnet', 2, isFard: false),
];

/// Rehberdeki tek adım (ekranda gösterilen kısa başlık + süre + titreşim).
class GuideStep {
  const GuideStep({
    required this.id,
    required this.title,
    required this.duration,
    required this.rakat,
    this.signal,
    this.audio,
  });

  final String id;
  final String title;
  final Duration duration;
  final int rakat;
  final Signal? signal;

  /// Doğrulanmış ses dosyası yolu (content/). Yoksa null.
  final String? audio;
}

/// Mezhebe göre akış şablonu (content/flows/*.json). Kodda dinî hüküm yok;
/// tüm sıralama ve süreler yapılandırma dosyasındadır ve uzman onayı bekler.
class FlowTemplate {
  FlowTemplate(this.json);

  final Map<String, dynamic> json;

  static Future<FlowTemplate> load(Madhab m, {AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(
      'content/flows/${m.name}.json',
    );
    return FlowTemplate(jsonDecode(raw) as Map<String, dynamic>);
  }

  String get status => json['status'] as String? ?? 'taslak';
  bool get verified => status == 'onaylandi';
  String get note => json['note'] as String? ?? '';

  List<Map<String, dynamic>> block(String name) =>
      ((json['blocks'] as Map<String, dynamic>)[name] as List? ?? const [])
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> get surahs =>
      json['surahs'] as Map<String, dynamic>? ?? const {};

  bool get kunutInSabahFarz => json['kunutInSabahFarz'] as bool? ?? false;
}

/// Zamm-ı sure adayları: Fatiha hariç, bilinen sureler mushaf sırasıyla.
List<String> zammCandidates(FlowTemplate t, List<String> known) {
  final list = known
      .where((s) => s != 'Fatiha' && t.surahs.containsKey(s))
      .toList();
  int order(String s) => (t.surahs[s] as Map<String, dynamic>)['number'] as int;
  list.sort((a, b) => order(a).compareTo(order(b)));
  return list;
}

/// Namaz akışını şablondan üretir.
List<GuideStep> buildGuide({
  required FlowTemplate template,
  required PrayerOption prayer,
  required List<String> knownSurahs,
  required ReadingSpeed speed,
}) {
  final steps = <GuideStep>[];
  final zamm = zammCandidates(template, knownSurahs);

  void addBlock(String name, int rakat, {Map<String, String> vars = const {}}) {
    for (final s in template.block(name)) {
      var title = s['title'] as String;
      vars.forEach((k, v) => title = title.replaceAll('{$k}', v));
      var seconds = (s['seconds'] as num).toDouble();
      if (s['secondsFrom'] == 'surah' && vars['surah'] != null) {
        final info = template.surahs[vars['surah']] as Map<String, dynamic>?;
        if (info != null) seconds = (info['seconds'] as num).toDouble();
      }
      final sig = s['signal'] as String?;
      steps.add(
        GuideStep(
          id: s['id'] as String,
          title: title,
          duration: Duration(
            milliseconds: (seconds * 1000 * speed.factor).round(),
          ),
          rakat: rakat,
          signal: sig == null ? null : Signal.values.byName(sig),
          audio: s['audio'] as String?,
        ),
      );
    }
  }

  final n = prayer.rakats;
  for (var r = 1; r <= n; r++) {
    addBlock(r == 1 ? 'opening' : 'rise', r);
    addBlock('fatiha', r);
    // Farzlarda zamm-ı sure ilk iki rekâtta; sünnetlerde her rekâtta.
    final readZamm = !prayer.isFard || r <= 2;
    if (readZamm) {
      final String surah;
      if (zamm.isEmpty) {
        surah = 'Zamm-ı sure';
      } else {
        surah = zamm[(r - 1) % zamm.length];
      }
      addBlock('zamm', r, vars: {'surah': surah});
    }
    addBlock('ruku', r);
    addBlock('rise_from_ruku', r);
    if (template.kunutInSabahFarz && prayer.id == 'sabah_farz' && r == 2) {
      addBlock('kunut', r);
    }
    addBlock('sujud', r);
    final isLast = r == n;
    if (!isLast && r == 2) addBlock('first_sitting', r);
    if (isLast) {
      addBlock('final_sitting', r);
      addBlock('salam', r);
    }
  }
  addBlock('end', n);
  return steps;
}

Duration totalDuration(List<GuideStep> steps) =>
    steps.fold(Duration.zero, (a, s) => a + s.duration);
