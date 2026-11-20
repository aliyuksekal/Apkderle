import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/guide_flow.dart';
import 'package:namaz_asistani/core/guide_runner.dart';
import 'package:namaz_asistani/core/settings.dart';
import 'package:namaz_asistani/core/vibration_patterns.dart';

PrayerOption opt(String id) => kPrayerOptions.firstWhere((p) => p.id == id);

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
    expect(steps.first.title, 'Allahu Ekber');
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
      prayer: opt('sabah_farz'),
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
}
