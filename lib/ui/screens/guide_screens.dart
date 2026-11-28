import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/duas.dart';
import '../../core/guide_audio.dart';
import '../../core/guide_flow.dart';
import '../../core/guide_runner.dart';
import '../../core/native.dart';
import '../../core/place.dart';
import '../../core/prayer_log.dart';
import '../../core/prayer_times.dart';
import '../../core/settings.dart';
import '../../core/speech.dart';
import '../../core/vibration_patterns.dart';
import '../app_scope.dart';
import '../widgets.dart';
import 'pro_screens.dart' show todayInfo;

/// Şu an hangi vaktin içindeyiz (Güneş–Öğle arası: null).
Vakit? currentVakit(PrayerTimes? t, DateTime now) {
  if (t == null) return null;
  if (now.isBefore(t[PrayerName.imsak])) return Vakit.yatsi;
  if (now.isBefore(t[PrayerName.gunes])) return Vakit.sabah;
  if (now.isBefore(t[PrayerName.ogle])) return null;
  if (now.isBefore(t[PrayerName.ikindi])) return Vakit.ogle;
  if (now.isBefore(t[PrayerName.aksam])) return Vakit.ikindi;
  if (now.isBefore(t[PrayerName.yatsi])) return Vakit.aksam;
  return Vakit.yatsi;
}

PrayerName _start(Vakit v) => switch (v) {
  Vakit.sabah => PrayerName.imsak,
  Vakit.ogle => PrayerName.ogle,
  Vakit.ikindi => PrayerName.ikindi,
  Vakit.aksam => PrayerName.aksam,
  Vakit.yatsi => PrayerName.yatsi,
};

/// 1) Beş vakit + kaza
class GuideSelectScreen extends StatelessWidget {
  const GuideSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final info = todayInfo(placeFromSettings(context.settings));
    final now = currentVakit(info.times, info.now);
    return Scaffold(
      appBar: AppBar(title: const Text('İmamla Kıl')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hangi vakti kılacaksınız?', style: t.headlineSmall),
            const SizedBox(height: 14),
            for (final v in Vakit.values) ...[
              BigActionButton(
                icon: Icons.mosque_rounded,
                label: '${v.label} Namazı',
                subtitle: [
                  if (info.times != null) hhmm(info.times![_start(v)]),
                  if (v == now) 'Şu anki vakit',
                ].join(' • '),
                gold: v == now,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => VakitScreen(vakit: v)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 6),
            BigActionButton(
              icon: Icons.history_rounded,
              label: 'Kaza Namazı',
              subtitle: 'Yalnız farzlar, kaza niyetiyle',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const KazaPickScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2a) Bir vaktin namazları: sünnetler + farz
class VakitScreen extends StatelessWidget {
  const VakitScreen({super.key, required this.vakit});
  final Vakit vakit;

  void _go(BuildContext context, List<PrayerUnit> units) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => GuidePrepScreen(units: units)));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final units = unitsFor(vakit, context.settings.madhab);
    final farz = units.firstWhere((u) => u.isFard);
    final total = units.fold<int>(0, (a, u) => a + u.rakats);
    return Scaffold(
      appBar: AppBar(title: Text('${vakit.label} Namazı')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BigActionButton(
              icon: Icons.playlist_play_rounded,
              label: 'Hepsini Kıl',
              subtitle:
                  '${units.map((u) => u.title.replaceFirst('${vakit.label} ', '')).join(' + ')} • $total rekât',
              gold: true,
              onPressed: () => _go(context, units),
            ),
            const SizedBox(height: 12),
            BigActionButton(
              icon: Icons.timer_rounded,
              label: 'Sadece Farzı Kıl',
              subtitle: 'Vakit darsa • ${farz.rakats} rekât',
              onPressed: () => _go(context, [farz]),
            ),
            const SizedBox(height: 20),
            Text('Tek tek kılmak için', style: t.titleLarge),
            const SizedBox(height: 10),
            for (final u in units) ...[
              _UnitTile(unit: u, onTap: () => _go(context, [u])),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.unit, required this.onTap, this.badge});
  final PrayerUnit unit;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final kind = switch (unit.kind) {
      UnitKind.farz => 'Farz',
      UnitKind.vitir => 'Vitir',
      _ => 'Sünnet',
    };
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unit.isFard ? cs.primary : cs.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${unit.rakats}',
                  style: t.headlineSmall!.copyWith(
                    color: unit.isFard ? cs.onPrimary : cs.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.title, style: t.titleLarge),
                    Text(
                      badge ?? '$kind • ${unit.rakats} rekât',
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded, size: 44),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2b) Kaza namazı: yalnızca farzlar (Hanefi'de vitir de)
class KazaPickScreen extends StatelessWidget {
  const KazaPickScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final log = context.log;
    final units = kazaUnits(context.settings.madhab);
    return Scaffold(
      appBar: AppBar(title: const Text('Kaza Namazı')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: log,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const NoticeBox(
                text:
                    'Kaza namazında yalnızca farz kılınır (Hanefi mezhebinde vitir de kaza edilir). İmam "kazaya kalan ilk … namazının farzını kılmaya" diye niyet eder.',
              ),
              const SizedBox(height: 14),
              for (final u in units) ...[
                _UnitTile(
                  unit: u,
                  badge:
                      '${u.rakats} rekât • borç: ${log.kaza[u.kazaKey] ?? 0}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GuidePrepScreen(units: [u]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              Text(
                'Rehberle kılınan her kaza, Kaza Sayacı\'ndaki borçtan bir düşer.',
                style: t.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dua okunuşları (rehber ekranında gösterilir).
Future<Map<String, String>> _duaTexts() async {
  final lib = await loadDuas();
  return {
    for (final d in lib.duas)
      if (d.category == 'Namaz Duaları')
        d.id: d.verses.map((v) => v.transliteration ?? '').join(' '),
  };
}

/// 3) Tek kısa hazırlık ekranı
class GuidePrepScreen extends StatefulWidget {
  const GuidePrepScreen({super.key, required this.units});
  final List<PrayerUnit> units;

  @override
  State<GuidePrepScreen> createState() => _GuidePrepScreenState();
}

class _GuidePrepScreenState extends State<GuidePrepScreen> {
  FlowTemplate? template;
  Map<String, String> duaTexts = const {};
  String? loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await FlowTemplate.load(context.settingsRead.madhab);
      final d = await _duaTexts();
      if (mounted) {
        setState(() {
          template = t;
          duaTexts = d;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => loadError = 'Namaz akışı yüklenemedi. Uygulamayı yeniden açın.',
        );
      }
    }
  }

  String get _title => widget.units.length == 1
      ? widget.units.single.title
      : '${widget.units.first.vakit.label} Namazı (hepsi)';

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    final t = Theme.of(context).textTheme;
    final tpl = template;
    final steps = tpl == null
        ? const <GuideStep>[]
        : buildSequence(
            template: tpl,
            units: widget.units,
            knownSurahs: s.knownSurahs,
            speed: s.readingSpeed,
            duaTexts: duaTexts,
          );
    final hasAudio = steps.any((x) => x.hasAudio);
    final zamm = tpl == null
        ? const <String>[]
        : zammCandidates(tpl, s.knownSurahs);
    final minutes = (totalDuration(steps).inSeconds / 60).ceil();

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final u in widget.units) Text(u.label, style: t.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${s.madhab.label} • ${s.readingSpeed.label}${steps.isEmpty ? '' : ' • yaklaşık $minutes dk'}',
              style: t.titleMedium,
            ),
            const SizedBox(height: 12),
            NoticeBox(
              icon: Icons.record_voice_over_rounded,
              text: 'Niyet: ${widget.units.first.niyet}',
            ),
            const SizedBox(height: 12),
            Text(
              'Telefonu seccadenizin yanına, güvenli bir yere koyun. Ses ve titreşimi kontrol edin.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 12),
            if (loadError != null) NoticeBox(text: loadError!, warning: true),
            if (tpl != null && !tpl.verified) ...[
              const NoticeBox(
                warning: true,
                text:
                    'TASLAK: Bu namaz akışı henüz yetkin bir dinî danışman tarafından onaylanmadı. Öğrenme ve eşlik amaçlı kullanın.',
              ),
              const SizedBox(height: 10),
            ],
            NoticeBox(
              icon: Icons.volume_up_rounded,
              text: hasAudio
                  ? 'Fatiha ve sureleri Hafız Mahmud Halil el-Husarî okur. Niyet, tekbir, tesbih ve dualar telefonun konuşma sesiyle okunur ve ekranda büyük yazıyla görünür.'
                  : 'Bu namazda ses kaydı yok; rehber titreşim ve ekrandaki büyük yazılarla ilerler.',
            ),
            const SizedBox(height: 10),
            FutureBuilder<bool?>(
              future: Speech.instance.turkishReady(),
              builder: (context, snap) => snap.data == false
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NoticeBox(
                            warning: true,
                            text:
                                'Telefonda Türkçe konuşma sesi yok. Niyet, tekbir ve dualar sesli okunamaz. Aşağıdaki düğmeden "Türkçe" sesini indirin.',
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: Speech.instance.openSettings,
                            icon: const Icon(Icons.record_voice_over_rounded),
                            label: const Text('Konuşma ayarlarını aç'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (tpl != null && zamm.isEmpty) ...[
              const NoticeBox(
                warning: true,
                text:
                    'Fatiha dışında bildiğiniz bir sure seçilmedi. Profil > Mezhep ve Sure Tercihleri\'nden ekleyebilirsiniz.',
              ),
              const SizedBox(height: 10),
            ],
            _signalLegend(context),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      NativeBridge.instance; // olay işleyicisi
                      AssetAudio.instance.play([
                        'content/audio/husary/001001.mp3',
                      ], speed: s.readingSpeed.audioRate);
                    },
                    icon: const Icon(Icons.volume_up_rounded, size: 28),
                    label: const Text('Sesi Dene'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => NativeBridge.instance.vibrate(
                      Signal.secde,
                      strong: true,
                    ),
                    icon: const Icon(Icons.vibration_rounded, size: 28),
                    label: const Text('Titreşimi Dene'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(84),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                textStyle: t.headlineSmall,
              ),
              onPressed: steps.isEmpty
                  ? null
                  : () {
                      AssetAudio.instance.stop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              GuideRunScreen(title: _title, steps: steps),
                        ),
                      );
                    },
              icon: const Icon(Icons.play_arrow_rounded, size: 40),
              label: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signalLegend(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(a, style: t.titleSmall)),
          Expanded(child: Text(b, style: t.bodyLarge)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Titreşim dili', style: t.titleLarge),
          row('1 kısa', 'Rükûya geçiş'),
          row('2 kısa', 'Secdeye geçiş'),
          row('1 uzun', 'Oturma / kalkma'),
          row('3 uzun', 'Namaz bitti'),
        ],
      ),
    );
  }
}

/// 4) Rehber çalışıyor — dokunmadan ilerler, durdurma her zaman açık.
class GuideRunScreen extends StatefulWidget {
  const GuideRunScreen({super.key, required this.title, required this.steps});
  final String title;
  final List<GuideStep> steps;

  @override
  State<GuideRunScreen> createState() => _GuideRunScreenState();
}

class _GuideRunScreenState extends State<GuideRunScreen> {
  late final GuideRunner runner;
  late final audio = GuideAudio(speed: s.readingSpeed.audioRate);
  StreamSubscription<void>? _stopSub;
  late final AppSettings s = context.settingsRead;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    runner = GuideRunner(
      steps: widget.steps,
      playAudio: audio.play,
      stopAudio: audio.stop,
      speak: (t) => Speech.instance.speak(t, rate: s.readingSpeed.speechRate),
      stopSpeech: Speech.instance.stop,
      onSignal: (sig) {
        if (s.vibrationOn) NativeBridge.instance.vibrate(sig, strong: true);
      },
      onStep: (st) {
        NativeBridge.instance.updateGuideService(
          '${st.unit?.title ?? ''} • ${st.rakat}. rekât • ${st.title}',
        );
        // Bir namaz bitince işaretle / kazadan düş.
        if (st.id == 'bitti' || st.id == 'bitti_ara') _completed(st.unit);
      },
    )..addListener(_onChange);
    _stopSub = NativeBridge.instance.guideStopRequests.listen((_) => _stop());
    _begin();
  }

  Future<void> _begin() async {
    if (s.keepAudioScreenOff) {
      await NativeBridge.instance.requestNotificationPermission();
      await NativeBridge.instance.startGuideService(
        '${widget.title} — rehber çalışıyor',
      );
    } else {
      await NativeBridge.instance.keepScreenOn(true);
    }
    // Hazırlık için kısa bekleme, sonra başla.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted && !runner.stopped) runner.start();
  }

  void _onChange() {
    if (runner.finished && !_closed) {
      _closed = true;
      _cleanup();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GuideDoneScreen()),
      );
    } else {
      setState(() {});
    }
  }

  /// Farz tamamlanınca "Bugün kıldıklarım"a işlenir; kaza ise borçtan düşer.
  void _completed(PrayerUnit? u) {
    if (u == null) return;
    final scope = context.scopeRead;
    if (u.kaza) {
      scope.log.payOne(u.kazaKey);
      return;
    }
    if (!u.isFard) return;
    final f = Farz.values.byName(u.vakit.name);
    final day = todayInfo(placeFromSettings(scope.settings)).day;
    scope.log.setMarked(day, f, true);
  }

  void _stop() {
    if (_closed) return;
    _closed = true;
    runner.stop();
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  void _cleanup() {
    audio.stop();
    NativeBridge.instance.stopGuideService();
    NativeBridge.instance.keepScreenOn(false);
  }

  @override
  void dispose() {
    _stopSub?.cancel();
    if (!_closed) {
      runner.stop();
      _cleanup();
    }
    runner.dispose();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final st = runner.current;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDialog(
          context,
          title: 'Rehber durdurulsun mu?',
          message: 'Namaz rehberi duracak.',
          yes: 'Durdur',
        )) {
          _stop();
        }
      },
      child: Scaffold(
        backgroundColor: cs.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  st?.unit?.title ?? widget.title,
                  textAlign: TextAlign.center,
                  style: t.titleLarge!.copyWith(color: cs.onPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  st == null
                      ? 'Hazırlanın…'
                      : '${st.rakat}. rekât / ${st.unit?.rakats ?? ''}',
                  style: t.headlineSmall!.copyWith(color: cs.secondary),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: runner.progress,
                    minHeight: 12,
                    color: cs.secondary,
                    backgroundColor: cs.onPrimary.withValues(alpha: .2),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              st?.title ?? 'Niyet ile başlayacak',
                              textAlign: TextAlign.center,
                              style: t.displaySmall!.copyWith(
                                color: cs.onPrimary,
                                fontSize: (st?.title.length ?? 0) > 40
                                    ? 30
                                    : 46,
                              ),
                            ),
                          ),
                          if (st?.detail != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              st!.detail!,
                              textAlign: TextAlign.center,
                              style: t.titleLarge!.copyWith(
                                color: cs.onPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (st?.signal != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      st!.signal!.label,
                      style: t.titleLarge!.copyWith(color: cs.secondary),
                    ),
                  ),
                Text(
                  'Ekrana dokunmanız gerekmez.',
                  style: t.bodyLarge!.copyWith(color: cs.onPrimary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    backgroundColor: cs.surface,
                    foregroundColor: cs.onSurface,
                  ),
                  onPressed: () async {
                    if (await confirmDialog(
                      context,
                      title: 'Rehber durdurulsun mu?',
                      message: 'Namaz rehberi duracak.',
                      yes: 'Durdur',
                    )) {
                      _stop();
                    }
                  },
                  icon: const Icon(Icons.stop_circle_rounded, size: 34),
                  label: const Text('Durdur'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 4) Tamamlandı
class GuideDoneScreen extends StatelessWidget {
  const GuideDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 140, color: cs.secondary),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Namaz Bitti',
                  textAlign: TextAlign.center,
                  style: t.headlineLarge,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Allah kabul etsin.',
                textAlign: TextAlign.center,
                style: t.headlineSmall,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.home_rounded, size: 32),
                label: const Text('Ana Sayfaya Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
