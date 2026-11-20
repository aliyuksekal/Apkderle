import 'package:flutter/material.dart';

import '../../core/family.dart';
import '../../core/native.dart';
import '../../core/place.dart';
import '../../core/prayer_log.dart';
import '../../core/prayer_times.dart';
import '../../core/reminders.dart';
import '../../core/settings.dart';
import '../app_scope.dart';
import '../widgets.dart';
import 'guide_screens.dart';
import 'profile_screen.dart' show PremiumScreen;
import 'zikr_screen.dart';

/// Pro özelliği açmak için: Pro ise sayfayı, değilse Pro ekranını aç.
void openPro(BuildContext context, Widget page) {
  final owned = context.premium.isPremium;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => owned ? page : const PremiumScreen(fromGuide: false),
    ),
  );
}

/// Bugünün yerel (konum saati) tarih anahtarı ve vakitleri.
({String day, PrayerTimes? times, DateTime now}) todayInfo(Place? place) {
  if (place == null) {
    final n = DateTime.now();
    return (day: PrayerLog.dayKey(n), times: null, now: n);
  }
  final now = place.nowLocal();
  final t = PrayerTimes.calculate(
    latitude: place.lat,
    longitude: place.lng,
    date: now,
    utcOffset: place.utcOffset,
  );
  return (day: PrayerLog.dayKey(now), times: t, now: now);
}

// ---------------------------------------------------------------------------
// Bugün kıldıklarım (ücretsiz)

class TodayMarksCard extends StatelessWidget {
  const TodayMarksCard({super.key, this.big = false});

  /// Nine Modu'nda daha büyük.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final log = context.log;
    final s = context.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([log, s]),
      builder: (context, _) {
        final info = todayInfo(placeFromSettings(s));
        return Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Bugün kıldıklarım', style: t.titleLarge),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = big ? 2 : (c.maxWidth > 560 ? 5 : 3);
                    const gap = 8.0;
                    final w = (c.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final f in Farz.values)
                          SizedBox(
                            width: w,
                            child: _MarkButton(
                              farz: f,
                              marked: log.isMarked(info.day, f),
                              started:
                                  info.times == null ||
                                  !info.times![f.start].isAfter(info.now),
                              big: big,
                              onTap: () => log.setMarked(
                                info.day,
                                f,
                                !log.isMarked(info.day, f),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.farz,
    required this.marked,
    required this.started,
    required this.onTap,
    this.big = false,
  });

  final Farz farz;
  final bool marked;
  final bool started;
  final bool big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fg = marked ? cs.onPrimary : cs.onSurface;
    return Semantics(
      button: true,
      checked: marked,
      label:
          '${farz.label}${marked ? ', kılındı' : (started ? ', kılmadım' : ', vakti henüz girmedi')}',
      excludeSemantics: true,
      child: Material(
        color: marked ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: started || marked ? onTap : null,
          child: Container(
            constraints: BoxConstraints(minHeight: big ? 96 : 70),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: marked ? cs.secondary : cs.outlineVariant,
                width: marked ? 3 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  marked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: big ? 40 : 30,
                  color: marked
                      ? cs.secondary
                      : fg.withValues(alpha: started ? 1 : .35),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    farz.label,
                    style: (big ? t.headlineSmall : t.titleMedium)!.copyWith(
                      color: fg.withValues(alpha: started || marked ? 1 : .45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kaza Namazı Otomatik Sayacı (Pro)

class KazaScreen extends StatelessWidget {
  const KazaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = context.log;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kaza Sayacı')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: log,
          builder: (context, _) {
            final hanefi = context.settings.madhab == Madhab.hanefi;
            final keys = kKazaKeys.where((k) => k != 'vitir' || hanefi);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Toplam kaza borcu',
                        style: t.titleMedium!.copyWith(color: cs.onPrimary),
                      ),
                      Text(
                        '${log.kazaTotal}',
                        style: t.displaySmall!.copyWith(
                          color: cs.secondary,
                          fontSize: 54,
                        ),
                      ),
                      Text(
                        'vakit',
                        style: t.titleMedium!.copyWith(color: cs.onPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const NoticeBox(
                  icon: Icons.autorenew_rounded,
                  text:
                      'Otomatik sayım açık: Bir vaktin süresi çıktığında Ana Sayfa\'daki "Bugün kıldıklarım" bölümünde işaretlenmemişse kazaya eklenir. Sonradan "kıldım" derseniz geri düşülür.',
                ),
                const SizedBox(height: 12),
                for (final k in keys)
                  Card(
                    color: cs.surfaceContainerHigh,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kazaLabel(k), style: t.titleLarge),
                                Text(
                                  '${log.kaza[k]} kaza',
                                  style: t.headlineSmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '${kazaLabel(k)} kazası ekle',
                            iconSize: 30,
                            onPressed: () => log.addOne(k),
                            icon: const Icon(Icons.add_rounded),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(110, 64),
                            ),
                            onPressed: (log.kaza[k] ?? 0) > 0
                                ? () => log.payOne(k)
                                : null,
                            child: const Text('Kıldım'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addDebt(context, hanefi),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Geçmiş borcu hesapla'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    if (await confirmDialog(
                      context,
                      title: 'Sayaçlar sıfırlansın mı?',
                      message: 'Tüm kaza sayıları 0 olacak.',
                      yes: 'Sıfırla',
                    )) {
                      await log.resetKaza();
                    }
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Sayaçları sıfırla'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addDebt(BuildContext context, bool hanefi) async {
    final years = TextEditingController();
    final months = TextEditingController();
    final r = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Geçmiş borç'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Namaz kılmadığınız süreyi yazın. Her vakte bu kadar gün eklenir${hanefi ? ' (vitir dahil)' : ''}.',
                style: Theme.of(c).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: years,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Yıl'),
                style: Theme.of(c).textTheme.titleLarge,
              ),
              TextField(
                controller: months,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ay'),
                style: Theme.of(c).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final y = int.tryParse(years.text.trim()) ?? 0;
              final m = int.tryParse(months.text.trim()) ?? 0;
              Navigator.pop(c, (y * 365 + m * 30).clamp(0, 365 * 80));
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (r != null && r > 0 && context.mounted) {
      await context.log.addDebtDays(r, includeVitir: hanefi);
    }
  }
}

// ---------------------------------------------------------------------------
// Namaz + İlaç Hatırlatma (Pro)

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  Future<void> _apply(BuildContext context) async {
    final scope = context.scopeRead;
    await scope.reminders.save();
    await ReminderScheduler.instance.reschedule(
      r: scope.reminders,
      place: placeFromSettings(scope.settings),
      enabled: scope.premium.isPremium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.reminders;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hatırlatmalar')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: r,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_rounded,
                        size: 32,
                      ),
                      title: const Text('Namaz vakti bildirimi'),
                      value: r.prayerOn,
                      onChanged: (v) async {
                        r.prayerOn = v;
                        if (v) {
                          await ReminderScheduler.instance.requestPermissions();
                        }
                        if (context.mounted) await _apply(context);
                      },
                    ),
                    if (r.prayerOn) ...[
                      for (final p in PrayerName.values)
                        CheckboxListTile(
                          value: r.prayers.contains(p),
                          title: Text(p.isPrayer ? p.label : 'Güneş (doğuş)'),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) {
                            v! ? r.prayers.add(p) : r.prayers.remove(p);
                            _apply(context);
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ne zaman?', style: t.titleMedium),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in const [0, 10, 15, 30])
                                  ChoiceChip(
                                    label: Text(
                                      m == 0 ? 'Vakit girince' : '$m dk önce',
                                      style: t.titleSmall,
                                    ),
                                    selected: r.minutesBefore == m,
                                    onSelected: (_) {
                                      r.minutesBefore = m;
                                      _apply(context);
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.medication_rounded, size: 32),
                  const SizedBox(width: 8),
                  Text('İlaçlarım', style: t.titleLarge),
                ],
              ),
              const SizedBox(height: 6),
              if (r.medicines.isEmpty)
                Text(
                  'Henüz ilaç eklenmedi. İlaç adları yalnızca bu telefonda saklanır.',
                  style: t.bodyMedium,
                ),
              for (final m in r.medicines)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: ListTile(
                    minTileHeight: 72,
                    title: Text(m.name),
                    subtitle: Text(m.times.join('  •  ')),
                    trailing: IconButton(
                      tooltip: '${m.name} sil',
                      iconSize: 30,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (await confirmDialog(
                          context,
                          title: 'İlaç silinsin mi?',
                          message: '${m.name} hatırlatmaları kaldırılacak.',
                          yes: 'Sil',
                        )) {
                          r.medicines.remove(m);
                          if (context.mounted) await _apply(context);
                        }
                      },
                    ),
                    onTap: () => _editMedicine(context, m),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(68),
                ),
                onPressed: () => _editMedicine(context, null),
                icon: const Icon(Icons.add_rounded, size: 30),
                label: const Text('İlaç Ekle'),
              ),
              const SizedBox(height: 14),
              const NoticeBox(
                text:
                    'Hatırlatmalar 14 gün ileriye kurulur ve uygulamayı her açtığınızda yenilenir. Bazı telefonlarda pil tasarrufu ayarından bu uygulamaya izin vermeniz gerekebilir.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editMedicine(BuildContext context, Medicine? m) async {
    final r = context.scopeRead.reminders;
    final name = TextEditingController(text: m?.name ?? '');
    final times = [...?m?.times];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(m == null ? 'İlaç ekle' : 'İlacı düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  autofocus: m == null,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(c).textTheme.titleLarge,
                  decoration: const InputDecoration(
                    labelText: 'İlaç adı (ör. Tansiyon ilacı)',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tm in times)
                      InputChip(
                        label: Text(
                          tm,
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                        onDeleted: () => set(() => times.remove(tm)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: c,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                      builder: (c, child) => MediaQuery(
                        data: MediaQuery.of(
                          c,
                        ).copyWith(alwaysUse24HourFormat: true),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      final s =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      if (!times.contains(s)) set(() => (times..add(s)).sort());
                    }
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Saat ekle'),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty || times.isEmpty
                  ? null
                  : () => Navigator.pop(c, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (m == null) {
      r.medicines.add(
        Medicine(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.text.trim(),
          times: times,
        ),
      );
    } else {
      m.name = name.text.trim();
      m.times = times;
    }
    await ReminderScheduler.instance.requestPermissions();
    if (context.mounted) await _apply(context);
  }
}

// ---------------------------------------------------------------------------
// Annem Kıldı Mı? — Aile Takibi

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  @override
  void initState() {
    super.initState();
    final f = context.scopeRead.family;
    if (context.scopeRead.premium.isPremium) f.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.family;
    final pro = context.premium.isPremium;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Annem Kıldı Mı?')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: f,
          builder: (context, _) => RefreshIndicator(
            onRefresh: f.refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Takip ettiklerim', style: t.headlineSmall),
                const SizedBox(height: 6),
                if (!pro)
                  NoticeBox(
                    icon: Icons.lock_rounded,
                    text:
                        'Ailenizin namazlarını takip etmek Pro pakete dahildir. Paylaşan kişinin Pro alması gerekmez.',
                  ),
                if (pro && f.following.isEmpty)
                  Text(
                    'Annenizin/babanızın telefonunda "Ailemle paylaş" açıp size gönderdiği kodu ekleyin.',
                    style: t.bodyLarge,
                  ),
                if (pro)
                  for (final p in f.following) _FollowCard(person: p),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(68),
                  ),
                  onPressed: pro
                      ? () => _addFollow(context)
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PremiumScreen(),
                          ),
                        ),
                  icon: Icon(
                    pro ? Icons.person_add_alt_1_rounded : Icons.lock_rounded,
                    size: 30,
                  ),
                  label: Text(pro ? 'Kod ile ekle' : "Pro'ya geç"),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                Text('Ailemle paylaş', style: t.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Ana Sayfa\'da işaretlediğiniz "Bugün kıldıklarım" bilgisi ve adınız, kodu verdiğiniz aile üyelerinizle paylaşılır. Başka bilgi gönderilmez. Bu bölüm ücretsizdir.',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (!f.sharing)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(68),
                      backgroundColor: cs.secondary,
                      foregroundColor: cs.onSecondary,
                    ),
                    onPressed: () => _startShare(context),
                    icon: const Icon(Icons.family_restroom_rounded, size: 30),
                    label: const Text('Paylaşımı başlat'),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Paylaşım kodunuz',
                          style: t.titleMedium!.copyWith(color: cs.onPrimary),
                        ),
                        SelectableText(
                          prettyCode(f.shareCode!),
                          style: t.displaySmall!.copyWith(
                            color: cs.secondary,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          f.pushing
                              ? 'Gönderiliyor…'
                              : f.pushError ??
                                    (f.lastPushOk == null
                                        ? 'Henüz gönderilmedi'
                                        : 'Son gönderim: ${hhmm(f.lastPushOk!)}'),
                          style: t.bodyMedium!.copyWith(color: cs.onPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: () => NativeBridge.instance.shareText(
                      'Namaz Asistanı\'nda beni takip etmek için bu kodu ekle: ${prettyCode(f.shareCode!)}',
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Kodu gönder (WhatsApp, SMS)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await confirmDialog(
                        context,
                        title: 'Paylaşım durdurulsun mu?',
                        message:
                            'Bilgileriniz sunucudan silinir ve kodu bilenler artık göremez.',
                        yes: 'Durdur',
                      )) {
                        await f.stopSharing();
                      }
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Paylaşımı durdur'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startShare(BuildContext context) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Adınız'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: Theme.of(c).textTheme.titleLarge,
          decoration: const InputDecoration(hintText: 'ör. Fatma'),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Başlat'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.scopeRead.family.startSharing(name.text);
    }
  }

  Future<void> _addFollow(BuildContext context) async {
    final code = TextEditingController();
    final label = TextEditingController();
    String? error;
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Takip et'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: Theme.of(c).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    labelText: 'Paylaşım kodu',
                    hintText: 'K7M2-QX9P',
                  ),
                ),
                TextField(
                  controller: label,
                  style: Theme.of(c).textTheme.titleLarge,
                  decoration: const InputDecoration(
                    labelText: 'Kim? (ör. Annem)',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  NoticeBox(text: error!, warning: true),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      set(() => busy = true);
                      final e = await context.scopeRead.family.follow(
                        code.text,
                        label.text,
                      );
                      if (e == null) {
                        if (c.mounted) Navigator.pop(c);
                      } else {
                        set(() {
                          busy = false;
                          error = e;
                        });
                      }
                    },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowCard extends StatelessWidget {
  const _FollowCard({required this.person});
  final FollowedPerson person;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final st = person.last;
    final today =
        st?.days[PrayerLog.dayKey(DateTime.now())] ?? const <String>{};
    return Card(
      color: cs.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_rounded, size: 34, color: cs.tertiary),
                const SizedBox(width: 8),
                Expanded(child: Text(person.label, style: t.titleLarge)),
                IconButton(
                  tooltip: 'Takibi bırak',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () async {
                    if (await confirmDialog(
                      context,
                      title: 'Takip bırakılsın mı?',
                      message: '${person.label} listeden çıkarılacak.',
                      yes: 'Bırak',
                    )) {
                      if (context.mounted) {
                        await context.scopeRead.family.unfollow(person);
                      }
                    }
                  },
                ),
              ],
            ),
            if (person.error != null)
              Text(person.error!, style: t.bodyMedium)
            else if (st != null) ...[
              Text(familySummary(st, DateTime.now()), style: t.bodyLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in Farz.values)
                    Chip(
                      avatar: Icon(
                        today.contains(f.name)
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: today.contains(f.name)
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: .4),
                      ),
                      label: Text(f.label, style: t.titleSmall),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Son güncelleme: ${st.updatedAt.day}.${st.updatedAt.month} ${hhmm(st.updatedAt)}',
                style: t.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nine Modu (Pro): sade ve çok büyük ana ekran

class NineHome extends StatelessWidget {
  const NineHome({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(
          (mq.textScaler.scale(1) * 1.2).clamp(1.0, 2.4),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) {
              final place = placeFromSettings(s);
              String headline = 'Şehrinizi seçin';
              String sub = '';
              if (place != null) {
                final now = place.nowLocal();
                final today = PrayerTimes.calculate(
                  latitude: place.lat,
                  longitude: place.lng,
                  date: now,
                  utcOffset: place.utcOffset,
                );
                final tomorrow = PrayerTimes.calculate(
                  latitude: place.lat,
                  longitude: place.lng,
                  date: now.add(const Duration(days: 1)),
                  utcOffset: place.utcOffset,
                );
                final n = findNextPrayer(
                  today: today,
                  tomorrow: tomorrow,
                  nowLocal: now,
                );
                headline = '${n.name.dative} ${formatRemaining(n.remaining)}';
                sub = '${place.name} • ${n.name.label} ${hhmm(n.time)}';
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              headline,
                              style: t.headlineLarge!.copyWith(
                                color: cs.secondary,
                              ),
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              sub,
                              textAlign: TextAlign.center,
                              style: t.titleLarge!.copyWith(
                                color: cs.onPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TodayMarksCard(big: true),
                  const SizedBox(height: 16),
                  BigActionButton(
                    icon: Icons.mosque_rounded,
                    label: 'İmamla Kıl',
                    gold: true,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuideSelectScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BigActionButton(
                    icon: Icons.adjust_rounded,
                    label: 'Zikirmatik',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ZikrScreen()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: TextButton.icon(
                      onPressed: onExit,
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Ayarlar ve normal görünüm'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
