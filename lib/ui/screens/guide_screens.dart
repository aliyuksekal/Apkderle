import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/guide_audio.dart';
import '../../core/guide_flow.dart';
import '../../core/guide_runner.dart';
import '../../core/native.dart';
import '../../core/place.dart';
import '../../core/prayer_log.dart';
import '../../core/settings.dart';
import '../../core/vibration_patterns.dart';
import '../app_scope.dart';
import '../widgets.dart';
import 'pro_screens.dart' show todayInfo;

/// 1) Namaz seçimi
class GuideSelectScreen extends StatelessWidget {
  const GuideSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İmamla Kıl')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hangi namazı kılacaksınız?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            for (final p in kPrayerOptions) ...[
              BigActionButton(
                icon: Icons.mosque_rounded,
                label: p.title,
                subtitle: '${p.rakats} rekât',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GuidePrepScreen(prayer: p)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// 2) Tek kısa hazırlık ekranı
class GuidePrepScreen extends StatefulWidget {
  const GuidePrepScreen({super.key, required this.prayer});
  final PrayerOption prayer;

  @override
  State<GuidePrepScreen> createState() => _GuidePrepScreenState();
}

class _GuidePrepScreenState extends State<GuidePrepScreen> {
  FlowTemplate? template;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await FlowTemplate.load(context.settingsRead.madhab);
      if (mounted) setState(() => template = t);
    } catch (e) {
      if (mounted) {
        setState(
          () => loadError = 'Namaz akışı yüklenemedi. Uygulamayı yeniden açın.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    final t = Theme.of(context).textTheme;
    final tpl = template;
    final steps = tpl == null
        ? const <GuideStep>[]
        : buildGuide(
            template: tpl,
            prayer: widget.prayer,
            knownSurahs: s.knownSurahs,
            speed: s.readingSpeed,
          );
    final hasAudio = steps.any((x) => x.hasAudio);
    final zamm = tpl == null
        ? const <String>[]
        : zammCandidates(tpl, s.knownSurahs);
    final minutes = (totalDuration(steps).inSeconds / 60).ceil();

    return Scaffold(
      appBar: AppBar(title: Text(widget.prayer.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.prayer.title} — ${widget.prayer.rakats} rekât',
              style: t.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${s.madhab.label} • ${s.readingSpeed.label}${steps.isEmpty ? '' : ' • yaklaşık $minutes dk'}',
              style: t.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Telefonu seccadenizin yanına, güvenli bir yere koyun. Ses ve titreşimi kontrol edin.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 16),
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
              icon: Icons.record_voice_over_rounded,
              text: hasAudio
                  ? 'Fatiha ve sureleri Hafız Mahmud Halil el-Husarî okur. Tekbir ve tesbihlerde ekranda büyük yazı ve titreşim olur.'
                  : 'Bu namazda ses kaydı yok; rehber titreşim ve ekrandaki büyük yazılarla ilerler.',
            ),
            const SizedBox(height: 10),
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
                    onPressed: () => NativeBridge.instance.tone('test'),
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
                  : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            GuideRunScreen(prayer: widget.prayer, steps: steps),
                      ),
                    ),
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

/// 3) Rehber çalışıyor — dokunmadan ilerler, durdurma her zaman açık.
class GuideRunScreen extends StatefulWidget {
  const GuideRunScreen({super.key, required this.prayer, required this.steps});
  final PrayerOption prayer;
  final List<GuideStep> steps;

  @override
  State<GuideRunScreen> createState() => _GuideRunScreenState();
}

class _GuideRunScreenState extends State<GuideRunScreen> {
  late final GuideRunner runner;
  final audio = GuideAudio();
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
      onSignal: (sig) {
        if (s.vibrationOn) NativeBridge.instance.vibrate(sig, strong: true);
      },
      onStep: (st) => NativeBridge.instance.updateGuideService(
        '${st.rakat}. rekât • ${st.title}',
      ),
    )..addListener(_onChange);
    _stopSub = NativeBridge.instance.guideStopRequests.listen((_) => _stop());
    _begin();
  }

  Future<void> _begin() async {
    if (s.keepAudioScreenOff) {
      await NativeBridge.instance.requestNotificationPermission();
      await NativeBridge.instance.startGuideService(
        '${widget.prayer.title} — rehber çalışıyor',
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
      _markPrayed();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GuideDoneScreen()),
      );
    } else {
      setState(() {});
    }
  }

  /// Farz namaz rehberle tamamlanınca "Bugün kıldıklarım"a işlenir.
  void _markPrayed() {
    final f = switch (widget.prayer.id) {
      'sabah_farz' => Farz.sabah,
      'ogle_farz' => Farz.ogle,
      'ikindi_farz' => Farz.ikindi,
      'aksam_farz' => Farz.aksam,
      'yatsi_farz' => Farz.yatsi,
      _ => null,
    };
    if (f == null) return;
    final scope = context.scopeRead;
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
                  widget.prayer.title,
                  style: t.titleLarge!.copyWith(color: cs.onPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  st == null
                      ? 'Hazırlanın…'
                      : '${st.rakat}. rekât / ${widget.prayer.rakats}',
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
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        st?.title ?? 'Allahu Ekber ile başlayacak',
                        textAlign: TextAlign.center,
                        style: t.displaySmall!.copyWith(
                          color: cs.onPrimary,
                          fontSize: 46,
                        ),
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
