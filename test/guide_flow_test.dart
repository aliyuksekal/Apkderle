import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/guide_flow.dart';
import 'package:namaz_asistani/core/guide_runner.dart';
import 'package:namaz_asistani/core/settings.dart';
import 'package:namaz_asistani/core/vibration_patterns.dart';

PrayerUnit opt(String id, [Madhab m = Madhab.hanefi]) =>
    Vakit.values.expand((v) => unitsFor(v, m)).firstWhere((u) => u.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Şablonlar taslak olarak işaretli (uzman onayı yok)', () async {
    for (final m in Madhab.values) {
      final t = await FlowTemplate.load(m);
      expect(t.verified, isFalse);
      expect(t.status, 'taslak');
    }
  });

  test('Hanefi sabah farzı: 2 rekât, işaret sırası doğru', () async {
    final t = await FlowTemplate.load(Madhab.hanefi);
    final steps = buildGuide(
      template: t,
      prayer: opt('sabah_farz'),
      knownSurahs: const ['Fatiha', 'İhlas', 'Kevser'],
      speed: ReadingSpeed.slow,
    );
    final signals = steps
        .where((s) => s.signal != null)
        .map((s) => s.signal)
        .toList();
    // Her rekâtta: rükû(1 kısa), kalkma(1 uzun), secde(2 kısa), celse(1 uzun), secde(2 kısa)
    final perRakat = [
      Signal.ruku,
      Signal.transition,
      Signal.secde,
      Signal.transition,
      Signal.secde,
    ];
    expect(signals, [
      ...perRakat, // 1. rekât
      Signal.transition, // 2. rekâta kalkış
      ...perRakat,
      Signal.transition, // son oturuşa geçiş
      Signal.done,
    ]);
    expect(steps.first.id, 'niyet');
    expect(
      steps.first.title,
      'Niyet ettim Allah rızası için bugünkü sabah namazının farzını kılmaya. Allahu Ekber',
    );
    expect(steps[1].title, 'Allahu Ekber');
    expect(steps.last.signal, Signal.done);
    expect(steps.map((s) => s.title), contains('Fatiha...'));
    // Zamm-ı sure mushaf sırasıyla: önce Kevser (108), sonra İhlas (112)
    final zamm = steps
        .where((s) => s.id == 'zamm')
        .map((s) => s.title)
        .toList();
    expect(zamm, ['Kevser...', 'İhlas...']);
  });

  test(
    '4 rekâtlı farzda ara oturuş var, zamm yalnızca ilk iki rekâtta',
    () async {
      final t = await FlowTemplate.load(Madhab.hanefi);
      final steps = buildGuide(
        template: t,
        prayer: opt('ogle_farz'),
        knownSurahs: const ['Fatiha', 'İhlas'],
        speed: ReadingSpeed.slow,
      );
      expect(steps.where((s) => s.id == 'zamm').length, 2);
      expect(
        steps.where((s) => s.id == 'tahiyyat').length,
        2,
      ); // ara + son oturuş
      expect(steps.where((s) => s.id == 'fatiha').length, 4);
      expect(steps.map((s) => s.rakat).toSet(), {1, 2, 3, 4});
    },
  );

  test('Akşam farzı 3 rekât: ara oturuş 2. rekâtta, selam sonda', () async {
    final t = await FlowTemplate.load(Madhab.hanefi);
    final steps = buildGuide(
      template: t,
      prayer: opt('aksam_farz'),
      knownSurahs: const ['Fatiha', 'İhlas'],
      speed: ReadingSpeed.slow,
    );
    final firstSit = steps.indexWhere((s) => s.id == 'tahiyyat');
    expect(steps[firstSit].rakat, 2);
    expect(
      steps.where((s) => s.id.startsWith('selam')).every((s) => s.rakat == 3),
      isTrue,
    );
  });

  test('Şafi sabah farzında kunut 2. rekâtta', () async {
    final t = await FlowTemplate.load(Madhab.safii);
    final steps = buildGuide(
      template: t,
      prayer: opt('sabah_farz', Madhab.safii),
      knownSurahs: const ['Fatiha', 'İhlas'],
      speed: ReadingSpeed.slow,
    );
    final k = steps.where((s) => s.id == 'kunut').toList();
    expect(k.length, 1);
    expect(k.single.rakat, 2);
  });

  test('Okuma hızı yalnızca süreleri ölçekler', () async {
    final t = await FlowTemplate.load(Madhab.hanefi);
    List<GuideStep> b(ReadingSpeed s) => buildGuide(
      template: t,
      prayer: opt('sabah_farz'),
      knownSurahs: const ['Fatiha', 'İhlas'],
      speed: s,
    );
    final slow = b(ReadingSpeed.slow), fast = b(ReadingSpeed.fast);
    expect(slow.length, fast.length);
    expect(slow.map((s) => s.title), fast.map((s) => s.title));
    expect(
      totalDuration(fast).inMilliseconds,
      closeTo(totalDuration(slow).inMilliseconds * 0.65, 50),
    );
  });

  test('Bilinen sure yoksa genel "Zamm-ı sure" başlığı', () async {
    final t = await FlowTemplate.load(Madhab.hanefi);
    final steps = buildGuide(
      template: t,
      prayer: opt('sabah_farz'),
      knownSurahs: const ['Fatiha'],
      speed: ReadingSpeed.slow,
    );
    expect(steps.where((s) => s.id == 'zamm').first.title, 'Zamm-ı sure...');
  });

  testWidgets('Rehber dokunmadan sonuna kadar ilerler ve durdurulabilir', (
    tester,
  ) async {
    final steps = [
      const GuideStep(
        id: 'a',
        title: 'A',
        duration: Duration(seconds: 1),
        rakat: 1,
      ),
      const GuideStep(
        id: 'b',
        title: 'B',
        duration: Duration(seconds: 1),
        rakat: 1,
        signal: Signal.ruku,
      ),
      const GuideStep(
        id: 'c',
        title: 'C',
        duration: Duration(seconds: 1),
        rakat: 1,
        signal: Signal.done,
      ),
    ];
    final fired = <Signal>[];
    final r = GuideRunner(steps: steps, onSignal: fired.add)..start();
    expect(r.current!.id, 'a');
    await tester.pump(const Duration(seconds: 1));
    expect(r.current!.id, 'b');
    await tester.pump(const Duration(seconds: 2));
    expect(r.finished, isTrue);
    expect(fired, [Signal.ruku, Signal.done]);

    final r2 = GuideRunner(steps: steps, onSignal: (_) {})..start();
    r2.stop();
    await tester.pump(const Duration(seconds: 5));
    expect(r2.stopped, isTrue);
    expect(r2.finished, isFalse);
    expect(r2.current!.id, 'a');
    r.dispose();
    r2.dispose();
  });

  test('Fatiha ve zamm-ı sure adımlarında hafız kaydı var', () async {
    final t = await FlowTemplate.load(Madhab.hanefi);
    final steps = buildGuide(
      template: t,
      prayer: opt('sabah_farz'),
      knownSurahs: const ['Fatiha', 'İhlas', 'Kevser'],
      speed: ReadingSpeed.slow,
    );
    final f = steps.firstWhere((s) => s.id == 'fatiha');
    expect(f.audioFiles.length, 7);
    expect(f.audioFiles.first, 'content/audio/husary/001001.mp3');
    final z = steps.where((s) => s.id == 'zamm').toList();
    expect(z[0].audioFiles.first, 'content/audio/husary/108001.mp3'); // Kevser
    expect(z[1].audioFiles.length, 4); // İhlas
    expect(steps.firstWhere((s) => s.id == 'ruku_tesbih').hasAudio, isFalse);
    for (final s in steps.expand((s) => s.audioFiles).toSet()) {
      final d = await rootBundle.load(s);
      expect(d.lengthInBytes, greaterThan(5000), reason: s);
    }
  });

  testWidgets('Sesli adım kayıt bitince ilerler, durdurunca ses de durur', (
    tester,
  ) async {
    final played = <List<String>>[];
    var stoppedAudio = 0;
    late Completer<void> c;
    final steps = [
      const GuideStep(
        id: 'fatiha',
        title: 'Fatiha...',
        duration: Duration(seconds: 99),
        rakat: 1,
        audioFiles: ['a.mp3', 'b.mp3'],
      ),
      const GuideStep(
        id: 'x',
        title: 'X',
        duration: Duration(seconds: 1),
        rakat: 1,
      ),
    ];
    final r = GuideRunner(
      steps: steps,
      onSignal: (_) {},
      playAudio: (f) {
        played.add(f);
        c = Completer<void>();
        return c.future;
      },
      stopAudio: () async => stoppedAudio++,
    )..start();
    expect(played.single, ['a.mp3', 'b.mp3']);
    await tester.pump(const Duration(seconds: 5));
    expect(r.current!.id, 'fatiha', reason: 'kayıt bitmeden ilerlemez');
    c.complete();
    await tester.pump();
    await tester.pump(GuideRunner.audioGap);
    expect(r.current!.id, 'x');
    r.stop();
    expect(stoppedAudio, 1);
    r.dispose();
  });

  test('Beş vakit: sünnetleriyle Hanefi rekât sayıları', () {
    String r(Vakit v) =>
        unitsFor(v, Madhab.hanefi).map((u) => u.rakats).join('+');
    expect(r(Vakit.sabah), '2+2');
    expect(r(Vakit.ogle), '4+4+2');
    expect(r(Vakit.ikindi), '4+4');
    expect(r(Vakit.aksam), '3+2');
    expect(r(Vakit.yatsi), '4+4+2+3');
  });

  test('Kaza: yalnız farzlar (+Hanefi vitir), kaza niyeti', () {
    final k = kazaUnits(Madhab.hanefi);
    expect(k.map((u) => u.kazaKey), [
      'sabah',
      'ogle',
      'ikindi',
      'aksam',
      'yatsi',
      'vitir',
    ]);
    expect(k.where((u) => u.isSunnet), isEmpty);
    expect(
      k.first.niyet,
      'Niyet ettim Allah rızası için kazaya kalan ilk sabah namazının farzını kılmaya. Allahu Ekber',
    );
    expect(kazaUnits(Madhab.safii).length, 5);
  });

  test(
    'Hanefi vitir: her rekâtta zamm, 3. rekâtta kunut rükûdan önce',
    () async {
      final t = await FlowTemplate.load(Madhab.hanefi);
      final steps = buildGuide(
        template: t,
        prayer: opt('yatsi_vitir'),
        knownSurahs: const ['Fatiha', 'İhlas', 'Kevser', 'Nas'],
        speed: ReadingSpeed.slow,
        duaTexts: const {'kunut1': 'Allâhümme innâ…'},
      );
      expect(steps.where((s) => s.id == 'zamm').length, 3);
      final k = steps.indexWhere((s) => s.id == 'kunut1');
      expect(steps[k].rakat, 3);
      expect(steps[k].detail, 'Allâhümme innâ…');
      final ruku3 = steps.indexWhere(
        (s) => s.id == 'tekbir_ruku' && s.rakat == 3,
      );
      expect(k, lessThan(ruku3));
    },
  );

  test(
    'İkindi sünneti (gayr-i müekked): ilk oturuşta Salli-Bârik, 3. rekâtta Sübhâneke',
    () async {
      final t = await FlowTemplate.load(Madhab.hanefi);
      final steps = buildGuide(
        template: t,
        prayer: opt('ikindi_sunnet'),
        knownSurahs: const ['Fatiha', 'İhlas'],
        speed: ReadingSpeed.slow,
      );
      expect(steps.where((s) => s.id == 'salli').map((s) => s.rakat), [2, 4]);
      expect(steps.where((s) => s.id == 'subhaneke').map((s) => s.rakat), [
        1,
        3,
      ]);
      final ogle = buildGuide(
        template: t,
        prayer: opt('ogle_ilk_sunnet'),
        knownSurahs: const ['Fatiha', 'İhlas'],
        speed: ReadingSpeed.slow,
      );
      expect(ogle.where((s) => s.id == 'salli').map((s) => s.rakat), [4]);
    },
  );

  test('Hepsini kıl: namazlar arka arkaya, arada geçiş, tek bitiş', () async {
    final t = await FlowTemplate.load(Madhab.hanefi);
    final units = unitsFor(Vakit.ogle, Madhab.hanefi);
    final steps = buildSequence(
      template: t,
      units: units,
      knownSurahs: const ['Fatiha', 'İhlas'],
      speed: ReadingSpeed.slow,
    );
    expect(steps.where((s) => s.id == 'niyet').length, 3);
    expect(steps.where((s) => s.id == 'bitti').length, 1);
    expect(steps.where((s) => s.id == 'bitti_ara').length, 2);
    expect(steps.last.unit!.id, 'ogle_son_sunnet');
    expect(
      steps.firstWhere((s) => s.id == 'ara').title,
      'Sıradaki: Öğle Farzı',
    );
  });

  test(
    'Kayıt olmayan adımlar sesli okunur: niyet, Sübhâneke, tesbih ×3',
    () async {
      final t = await FlowTemplate.load(Madhab.hanefi);
      final steps = buildGuide(
        template: t,
        prayer: opt('sabah_farz'),
        knownSurahs: const ['Fatiha', 'İhlas'],
        speed: ReadingSpeed.slow,
        duaTexts: const {'subhaneke': 'Sübhânekellâhümme ve bi hamdik'},
      );
      final niyet = steps.firstWhere((s) => s.id == 'niyet');
      expect(niyet.speech, startsWith('Niyet ettim Allah rızası için'));
      expect(
        steps.firstWhere((s) => s.id == 'subhaneke').speech,
        'Sübhânekellâhümme ve bi hamdik',
      );
      final tesbih = steps.firstWhere((s) => s.id == 'ruku_tesbih').speech!;
      expect('Azim'.allMatches(tesbih).length, 3);
      expect(
        steps.firstWhere((s) => s.id == 'fatiha').speech,
        isNull,
        reason: 'hafız kaydı olan adım konuşma motoruyla okunmaz',
      );
    },
  );

  testWidgets('Okunan adım okuma bitince ilerler', (tester) async {
    late Completer<bool> c;
    final spoken = <String>[];
    final r = GuideRunner(
      steps: const [
        GuideStep(
          id: 'niyet',
          title: 'Niyet',
          speech: 'Niyet ettim',
          duration: Duration(seconds: 2),
          rakat: 1,
        ),
        GuideStep(
          id: 'x',
          title: 'X',
          duration: Duration(seconds: 1),
          rakat: 1,
        ),
      ],
      onSignal: (_) {},
      speak: (t) {
        spoken.add(t);
        c = Completer<bool>();
        return c.future;
      },
    )..start();
    expect(spoken, ['Niyet ettim']);
    await tester.pump(const Duration(seconds: 5));
    expect(r.current!.id, 'niyet', reason: 'okuma bitmeden geçmez');
    c.complete(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(r.current!.id, 'x');
    r.dispose();
  });

  test('Hızlar yaklaşık %25 arttı', () {
    expect(ReadingSpeed.slow.factor, 0.8);
    expect(ReadingSpeed.slow.audioRate, greaterThan(1.2));
    expect(
      ReadingSpeed.fast.audioRate,
      greaterThan(ReadingSpeed.normal.audioRate),
    );
  });
}
