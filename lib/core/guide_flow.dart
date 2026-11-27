import 'dart:convert';

import 'package:flutter/services.dart';

import 'settings.dart';
import 'vibration_patterns.dart';

/// Beş vakit (Güneş hariç).
enum Vakit { sabah, ogle, ikindi, aksam, yatsi }

extension VakitX on Vakit {
  String get label => switch (this) {
    Vakit.sabah => 'Sabah',
    Vakit.ogle => 'Öğle',
    Vakit.ikindi => 'İkindi',
    Vakit.aksam => 'Akşam',
    Vakit.yatsi => 'Yatsı',
  };

  /// "öğle namazının" gibi tamlayan hâli niyet için.
  String get genitive => switch (this) {
    Vakit.sabah => 'sabah namazının',
    Vakit.ogle => 'öğle namazının',
    Vakit.ikindi => 'ikindi namazının',
    Vakit.aksam => 'akşam namazının',
    Vakit.yatsi => 'yatsı namazının',
  };
}

enum UnitKind {
  /// Farz (zamm-ı sure ilk iki rekâtta).
  farz,

  /// Müekked sünnet (4 rekâtlıda ilk oturuşta yalnız Ettehiyyâtü).
  sunnetMuekked,

  /// Gayr-i müekked sünnet (ilk oturuşta Salli-Bârik, 3. rekâtta Sübhâneke).
  sunnetGayri,

  /// Vitir (Hanefi'de vacip; 3. rekâtta kunut).
  vitir,
}

/// Bir vaktin içindeki tek namaz (ör. Öğlenin ilk sünneti, 4 rekât).
class PrayerUnit {
  const PrayerUnit({
    required this.id,
    required this.vakit,
    required this.title,
    required this.rakats,
    required this.kind,
    required this.niyetPart,
    this.kaza = false,
  });

  final String id;
  final Vakit vakit;
  final String title;
  final int rakats;
  final UnitKind kind;

  /// Niyet cümlesindeki kısım: "ilk sünnetini", "farzını"…
  final String niyetPart;
  final bool kaza;

  bool get isFard => kind == UnitKind.farz;
  bool get isSunnet =>
      kind == UnitKind.sunnetMuekked || kind == UnitKind.sunnetGayri;

  String get label => '$title — $rakats rekât';

  /// Kaza sayacındaki anahtar (sabah, ogle, …, vitir).
  String get kazaKey => kind == UnitKind.vitir ? 'vitir' : vakit.name;

  /// İmamın başta söylediği niyet.
  String get niyet {
    if (kind == UnitKind.vitir) {
      return kaza
          ? 'Niyet ettim Allah rızası için kazaya kalan ilk vitir namazını kılmaya. Allahu Ekber'
          : 'Niyet ettim Allah rızası için vitir namazını kılmaya. Allahu Ekber';
    }
    if (kaza) {
      return 'Niyet ettim Allah rızası için kazaya kalan ilk ${vakit.genitive} farzını kılmaya. Allahu Ekber';
    }
    return 'Niyet ettim Allah rızası için bugünkü ${vakit.genitive} $niyetPart kılmaya. Allahu Ekber';
  }

  PrayerUnit asKaza() => PrayerUnit(
    id: 'kaza_$id',
    vakit: vakit,
    title: 'Kaza: $title',
    rakats: rakats,
    kind: kind,
    niyetPart: niyetPart,
    kaza: true,
  );
}

PrayerUnit _u(
  Vakit v,
  String id,
  String title,
  int r,
  UnitKind k,
  String niyetPart,
) => PrayerUnit(
  id: '${v.name}_$id',
  vakit: v,
  title: title,
  rakats: r,
  kind: k,
  niyetPart: niyetPart,
);

/// Vaktin namazları, kılınış sırasıyla. (Dinî danışman onayı bekler.)
List<PrayerUnit> unitsFor(Vakit v, Madhab m) {
  const f = UnitKind.farz, mu = UnitKind.sunnetMuekked;
  const ga = UnitKind.sunnetGayri, vi = UnitKind.vitir;
  final hanefi = m == Madhab.hanefi;
  return switch (v) {
    Vakit.sabah => [
      _u(v, 'sunnet', 'Sabah Sünneti', 2, mu, 'sünnetini'),
      _u(v, 'farz', 'Sabah Farzı', 2, f, 'farzını'),
    ],
    Vakit.ogle => [
      _u(
        v,
        'ilk_sunnet',
        'Öğle İlk Sünneti',
        hanefi ? 4 : 2,
        mu,
        'ilk sünnetini',
      ),
      _u(v, 'farz', 'Öğle Farzı', 4, f, 'farzını'),
      _u(v, 'son_sunnet', 'Öğle Son Sünneti', 2, mu, 'son sünnetini'),
    ],
    Vakit.ikindi => [
      _u(v, 'sunnet', 'İkindi Sünneti', hanefi ? 4 : 2, ga, 'sünnetini'),
      _u(v, 'farz', 'İkindi Farzı', 4, f, 'farzını'),
    ],
    Vakit.aksam => [
      _u(v, 'farz', 'Akşam Farzı', 3, f, 'farzını'),
      _u(v, 'sunnet', 'Akşam Sünneti', 2, mu, 'sünnetini'),
    ],
    Vakit.yatsi => [
      if (hanefi)
        _u(v, 'ilk_sunnet', 'Yatsı İlk Sünneti', 4, ga, 'ilk sünnetini'),
      _u(v, 'farz', 'Yatsı Farzı', 4, f, 'farzını'),
      _u(v, 'son_sunnet', 'Yatsı Son Sünneti', 2, mu, 'son sünnetini'),
      if (hanefi)
        _u(v, 'vitir', 'Vitir Namazı', 3, vi, 'vitir')
      else ...[
        _u(v, 'vitir', 'Vitir (2 rekât)', 2, vi, 'vitir'),
        _u(v, 'vitir_tek', 'Vitir (1 rekât)', 1, vi, 'vitir'),
      ],
    ],
  };
}

/// Kaza bölümü: yalnızca farzlar (Hanefi'de vitir de kaza edilir).
List<PrayerUnit> kazaUnits(Madhab m) => [
  for (final v in Vakit.values)
    unitsFor(v, m).firstWhere((u) => u.isFard).asKaza(),
  if (m == Madhab.hanefi)
    unitsFor(
      Vakit.yatsi,
      m,
    ).firstWhere((u) => u.kind == UnitKind.vitir).asKaza(),
];

/// Rehberdeki tek adım (ekranda gösterilen kısa başlık + süre + titreşim).
class GuideStep {
  const GuideStep({
    required this.id,
    required this.title,
    required this.duration,
    required this.rakat,
    this.signal,
    this.audioFiles = const [],
    this.unit,
    this.detail,
  });

  final String id;
  final String title;
  final Duration duration;
  final int rakat;
  final Signal? signal;

  /// Adımın ait olduğu namaz (ör. Öğle Farzı).
  final PrayerUnit? unit;

  /// Ekranda başlığın altında gösterilen okunuş (Ettehiyyâtü vb.).
  final String? detail;

  /// Hafız kaydı (ayet ayet, sırayla çalınır). Boşsa adım [duration] kadar
  /// sürer; doluysa kayıt bitince ilerler.
  final List<String> audioFiles;

  bool get hasAudio => audioFiles.isNotEmpty;
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

/// Bir namazın akışını şablondan üretir.
/// [duaTexts]: dua kimliği → okunuşu (ekranda gösterilir).
List<GuideStep> buildGuide({
  required FlowTemplate template,
  required PrayerUnit prayer,
  required List<String> knownSurahs,
  required ReadingSpeed speed,
  Map<String, String> duaTexts = const {},
  bool withNiyet = true,
}) {
  final steps = <GuideStep>[];
  final zamm = zammCandidates(template, knownSurahs);
  final hanefi = template.json['madhab'] == 'hanefi';

  void addBlock(String name, int rakat, {Map<String, String> vars = const {}}) {
    for (final s in template.block(name)) {
      var title = s['title'] as String;
      vars.forEach((k, v) => title = title.replaceAll('{$k}', v));
      var seconds = (s['seconds'] as num).toDouble();
      final surahName =
          s['surah'] as String? ??
          (s['secondsFrom'] == 'surah' ? vars['surah'] : null);
      final info = surahName == null
          ? null
          : template.surahs[surahName] as Map<String, dynamic>?;
      if (info != null && s['secondsFrom'] == 'surah') {
        seconds = (info['seconds'] as num).toDouble();
      }
      final audio = info != null && info['verified'] == true
          ? ((info['audio'] as List?) ?? const []).cast<String>()
          : const <String>[];
      final sig = s['signal'] as String?;
      final duaIds = (s['dua'] as String?)?.split(',') ?? const <String>[];
      final detail = duaIds
          .map((id) => duaTexts[id])
          .whereType<String>()
          .join('\n');
      steps.add(
        GuideStep(
          id: s['id'] as String,
          title: title,
          duration: Duration(
            milliseconds: (seconds * 1000 * speed.factor).round(),
          ),
          rakat: rakat,
          signal: sig == null ? null : Signal.values.byName(sig),
          audioFiles: audio,
          unit: prayer,
          detail: detail.isEmpty ? null : detail,
        ),
      );
    }
  }

  final n = prayer.rakats;
  final gayri = hanefi && prayer.kind == UnitKind.sunnetGayri;
  if (withNiyet) addBlock('niyet', 1, vars: {'niyet': prayer.niyet});
  for (var r = 1; r <= n; r++) {
    addBlock(r == 1 ? 'opening' : 'rise', r);
    // Gayr-i müekked sünnette 3. rekât Sübhâneke ile başlar.
    if (gayri && r == 3) addBlock('subhaneke_only', r);
    addBlock('fatiha', r);
    // Farzlarda zamm-ı sure ilk iki rekâtta; sünnet ve vitirde her rekâtta.
    final readZamm = !prayer.isFard || r <= 2;
    if (readZamm) {
      final surah = zamm.isEmpty ? 'Zamm-ı sure' : zamm[(r - 1) % zamm.length];
      addBlock('zamm', r, vars: {'surah': surah});
    }
    // Hanefi vitir: son rekâtta rükûdan önce tekbir ve Kunut duaları.
    if (hanefi && prayer.kind == UnitKind.vitir && r == n) {
      addBlock('vitir_kunut', r);
    }
    addBlock('ruku', r);
    addBlock('rise_from_ruku', r);
    if (template.kunutInSabahFarz &&
        prayer.vakit == Vakit.sabah &&
        prayer.isFard &&
        r == 2) {
      addBlock('kunut', r);
    }
    addBlock('sujud', r);
    final isLast = r == n;
    if (!isLast && r == 2) {
      addBlock(gayri ? 'first_sitting_full' : 'first_sitting', r);
    }
    if (isLast) {
      addBlock('final_sitting', r);
      addBlock('salam', r);
    }
  }
  addBlock('end', n);
  return steps;
}

/// Birden çok namazı arka arkaya (ör. öğlenin sünnetleri ve farzı).
List<GuideStep> buildSequence({
  required FlowTemplate template,
  required List<PrayerUnit> units,
  required List<String> knownSurahs,
  required ReadingSpeed speed,
  Map<String, String> duaTexts = const {},
}) {
  final out = <GuideStep>[];
  for (var i = 0; i < units.length; i++) {
    final part = buildGuide(
      template: template,
      prayer: units[i],
      knownSurahs: knownSurahs,
      speed: speed,
      duaTexts: duaTexts,
    );
    if (i < units.length - 1) {
      // Son namazın dışında "Namaz bitti" yerine kısa bir geçiş.
      final end = part.removeLast();
      out.addAll(part);
      out.add(
        GuideStep(
          id: 'bitti_ara',
          title: '${units[i].title} bitti',
          duration: end.duration,
          rakat: end.rakat,
          signal: Signal.transition,
          unit: units[i],
        ),
      );
      for (final s in template.block('between')) {
        out.add(
          GuideStep(
            id: s['id'] as String,
            title: (s['title'] as String).replaceAll(
              '{next}',
              units[i + 1].title,
            ),
            duration: Duration(
              milliseconds: ((s['seconds'] as num) * 1000).round(),
            ),
            rakat: 1,
            unit: units[i + 1],
          ),
        );
      }
    } else {
      out.addAll(part);
    }
  }
  return out;
}

Duration totalDuration(List<GuideStep> steps) =>
    steps.fold(Duration.zero, (a, s) => a + s.duration);
