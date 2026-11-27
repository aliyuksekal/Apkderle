import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/place.dart';
import '../../core/prayer_times.dart';
import '../../core/settings.dart';
import '../../core/vibration_patterns.dart';
import '../app_scope.dart';
import '../widgets.dart';
import 'city_picker_screen.dart';
import 'pro_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil / Ayarlar')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final place = placeFromSettings(s);
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _Card(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.location_on_rounded, size: 34),
                      title: const Text('Şehir Seçimi'),
                      subtitle: Text(place?.name ?? 'Seçilmedi'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 32,
                      ),
                      onTap: () => _push(context, const CityPickerScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PremiumTile(
                  onTap: () => _push(context, const PremiumScreen()),
                ),
                const SizedBox(height: 12),
                _Card(
                  children: [
                    _sectionTitle(context, 'Pro Özellikler'),
                    _proTile(
                      context,
                      Icons.notifications_active_rounded,
                      'Namaz + İlaç Hatırlatma',
                      'Vakit ve ilaç saatinde bildirim',
                      const RemindersScreen(),
                    ),
                    _proTile(
                      context,
                      Icons.calculate_rounded,
                      'Kaza Namazı Sayacı',
                      'Kılınmayan vakitler otomatik sayılır',
                      const KazaScreen(),
                    ),
                    SwitchListTile(
                      secondary: Icon(
                        context.premium.isPremium
                            ? Icons.elderly_rounded
                            : Icons.lock_rounded,
                        size: 32,
                      ),
                      title: const Text('Nine Modu'),
                      subtitle: const Text('Çok büyük yazı, sade ana ekran'),
                      value: s.nineMode && context.premium.isPremium,
                      onChanged: (v) {
                        if (!context.premium.isPremium) {
                          _push(context, const PremiumScreen());
                          return;
                        }
                        s.setNineMode(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  children: [
                    _sectionTitle(context, 'Kolay Kullanım'),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.text_increase_rounded,
                        size: 32,
                      ),
                      title: const Text('Büyük Yazı ve Kolay Kullanım'),
                      value: s.largeText,
                      onChanged: s.setLargeText,
                    ),
                    ListTile(
                      leading: const Icon(Icons.dark_mode_rounded, size: 32),
                      title: const Text('Görünüm'),
                      subtitle: Text(switch (s.themeMode) {
                        ThemeMode.system => 'Telefona göre',
                        ThemeMode.light => 'Açık',
                        ThemeMode.dark => 'Koyu',
                      }),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 32,
                      ),
                      onTap: () => _choose<ThemeMode>(
                        context,
                        title: 'Görünüm',
                        values: ThemeMode.values,
                        current: s.themeMode,
                        label: (m) => switch (m) {
                          ThemeMode.system => 'Telefona göre',
                          ThemeMode.light => 'Açık',
                          ThemeMode.dark => 'Koyu',
                        },
                        onPick: s.setThemeMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  children: [
                    _sectionTitle(context, 'Ses ve Titreşim'),
                    ListTile(
                      leading: const Icon(Icons.speed_rounded, size: 32),
                      title: const Text('Okuma Hızı'),
                      subtitle: Text(s.readingSpeed.label),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 32,
                      ),
                      onTap: () => _choose<ReadingSpeed>(
                        context,
                        title: 'Okuma Hızı',
                        values: ReadingSpeed.values,
                        current: s.readingSpeed,
                        label: (v) => v.label,
                        onPick: s.setReadingSpeed,
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_rounded, size: 32),
                      title: const Text('Titreşim'),
                      value: s.vibrationOn,
                      onChanged: s.setVibration,
                    ),
                    ListTile(
                      leading: const Icon(Icons.touch_app_rounded, size: 32),
                      title: const Text('Titreşim Dilini Dene'),
                      subtitle: const Text('Rükû, secde, oturma, bitiş'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 32,
                      ),
                      onTap: () => _push(context, const VibrationTestScreen()),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up_rounded, size: 32),
                      title: const Text('Sesli Geri Bildirim'),
                      subtitle: const Text('Zikirmatik dokunuş sesi'),
                      value: s.soundFeedback,
                      onChanged: s.setSoundFeedback,
                    ),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.screen_lock_portrait_rounded,
                        size: 32,
                      ),
                      title: const Text('Ekran kararsa ses devam etsin'),
                      subtitle: const Text(
                        'Rehber sırasında kalıcı bir bildirim görünür. Bazı telefonlarda pil tasarrufu ayarından bu uygulamaya izin vermeniz gerekebilir.',
                      ),
                      isThreeLine: true,
                      value: s.keepAudioScreenOff,
                      onChanged: s.setKeepAudioScreenOff,
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.record_voice_over_rounded,
                        size: 32,
                      ),
                      title: const Text(
                        'Ekran okuyucu zikir sayısını söylesin',
                      ),
                      subtitle: Text(switch (s.zikrAnnounce) {
                        ZikrAnnounce.everyTap => 'Her dokunuşta',
                        ZikrAnnounce.everyTen => 'Her 10 zikirde',
                        ZikrAnnounce.off => 'Kapalı',
                      }),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 32,
                      ),
                      onTap: () => _choose<ZikrAnnounce>(
                        context,
                        title: 'Zikir sayısını söyleme',
                        values: ZikrAnnounce.values,
                        current: s.zikrAnnounce,
                        label: (v) => switch (v) {
                          ZikrAnnounce.everyTap => 'Her dokunuşta',
                          ZikrAnnounce.everyTen => 'Her 10 zikirde',
                          ZikrAnnounce.off => 'Kapalı',
                        },
                        onPick: s.setZikrAnnounce,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  children: [
                    _sectionTitle(context, 'Namaz Rehberi'),
                    ListTile(
                      leading: const Icon(Icons.menu_book_rounded, size: 32),
                      title: const Text('Mezhep ve Sure Tercihleri'),
                      subtitle: Text(
                        '${s.madhab.label} • ${s.knownSurahs.length} sure',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 32,
                      ),
                      onTap: () => _push(context, const MadhabSurahScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_rounded, size: 32),
                      title: const Text('Uygulama Hakkında'),
                      subtitle: const Text('Gizlilik, izinler, kaynaklar'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 32,
                      ),
                      onTap: () => _push(context, const AboutScreen()),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  static Widget _proTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page, {
    bool lockedOpens = false,
  }) {
    final pro = context.premium.isPremium;
    return ListTile(
      leading: Icon(pro || lockedOpens ? icon : Icons.lock_rounded, size: 32),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, size: 32),
      onTap: () => pro || lockedOpens
          ? _push(context, page)
          : _push(context, const PremiumScreen()),
    );
  }

  static Widget _sectionTitle(BuildContext context, String t) => Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Semantics(
      header: true,
      child: Text(t, style: Theme.of(context).textTheme.titleLarge),
    ),
  );

  static Future<void> _choose<T>(
    BuildContext context, {
    required String title,
    required List<T> values,
    required T current,
    required String Function(T) label,
    required Future<void> Function(T) onPick,
  }) async {
    final v = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(title, style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 12),
            for (final x in values) ...[
              ChoiceButton(
                label: label(x),
                selected: x == current,
                onTap: () => Navigator.pop(c, x),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
    if (v != null) await onPick(v);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _PremiumTile extends StatelessWidget {
  const _PremiumTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 40,
                color: cs.onSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.premium.isPremium
                          ? "Pro Paket etkin"
                          : "Pro Pakete Geç",
                      style: Theme.of(context).textTheme.headlineSmall!
                          .copyWith(color: cs.onSecondary),
                    ),
                    Text(
                      context.premium.isPremium
                          ? 'Allah razı olsun, destek için teşekkürler'
                          : 'Sanal imam, aile takibi, hatırlatma…',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: cs.onSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 32,
                color: cs.onSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class VibrationTestScreen extends StatelessWidget {
  const VibrationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final signals = [Signal.ruku, Signal.secde, Signal.transition, Signal.done];
    return Scaffold(
      appBar: AppBar(title: const Text('Titreşim Dili')),
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: NativeBridge.instance.hasVibrator(),
          builder: (context, snap) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (snap.data == false)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: NoticeBox(
                    warning: true,
                    text:
                        'Bu telefonda titreşim motoru bulunamadı. Rehberde geçişler ekranda büyük yazıyla gösterilir.',
                  ),
                ),
              if (!context.settings.vibrationOn)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: NoticeBox(
                    warning: true,
                    text: 'Titreşim ayarlardan kapalı. Deneme yine de çalışır.',
                  ),
                ),
              for (final s in signals) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(76),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () =>
                      NativeBridge.instance.vibrate(s, strong: true),
                  icon: const Icon(Icons.vibration_rounded, size: 32),
                  label: Text(s.label),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MadhabSurahScreen extends StatelessWidget {
  const MadhabSurahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Mezhep ve Sureler')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Mezhebiniz', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final m in Madhab.values) ...[
                ChoiceButton(
                  label: m.label,
                  selected: s.madhab == m,
                  onTap: () => s.setMadhab(m),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              Text(
                'Bildiğiniz sureler',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Rehber yalnızca seçtiğiniz sureleri kullanır.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              for (final x in kSelectableSurahs)
                CheckboxListTile(
                  value: s.knownSurahs.contains(x),
                  onChanged: x == 'Fatiha'
                      ? null
                      : (v) {
                          final l = [...s.knownSurahs];
                          v! ? l.add(x) : l.remove(x);
                          s.setKnownSurahs(l);
                        },
                  title: Text(x),
                  subtitle: x == 'Fatiha'
                      ? const Text('Her namazda okunur')
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key, this.fromGuide = false});

  /// "İmamla Kıl"a basılarak gelindiyse üstte açıklama gösterilir.
  final bool fromGuide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final store = context.premium;
    const perks = [
      (
        Icons.mosque_rounded,
        'Sanal İmam (Eller Serbest)',
        'Hafız Husarî Fatiha ve sureleri okur; rükû, secde ve oturuşlarda titreşimle yönlendirir. Ekran kararsa da devam eder.',
      ),
      (
        Icons.notifications_active_rounded,
        'Namaz + İlaç Hatırlatma',
        'Vakit girince ve ilaç saatinde bildirim.',
      ),
      (
        Icons.calculate_rounded,
        'Kaza Namazı Otomatik Sayacı',
        'Kılınmayan vakitler kendiliğinden kazaya yazılır; geçmiş borç hesaplanır.',
      ),
      (
        Icons.elderly_rounded,
        'Nine Modu',
        'Çok büyük yazı ve yalnızca en gerekli düğmeler.',
      ),
      (
        Icons.block_rounded,
        'Reklamsız kullanım',
        'Hiçbir ekranda reklam görünmez.',
      ),
      (
        Icons.all_inclusive_rounded,
        'Tek seferlik ödeme',
        'Abonelik yok. Aynı Google hesabıyla yeni telefonda da geçerli.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Pro Paket')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                store.isPremium
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_rounded,
                size: 80,
                color: cs.secondary,
              ),
              Text(
                store.isPremium ? 'Pro Paket Etkin' : 'Pro Paket',
                textAlign: TextAlign.center,
                style: t.headlineMedium,
              ),
              if (fromGuide && !store.isPremium) ...[
                const SizedBox(height: 12),
                const NoticeBox(
                  icon: Icons.lock_rounded,
                  text:
                      "İmamla Kıl (sanal imam) Pro pakete dahildir. Vakitler, zikirmatik, kıble, sesli dualar ve günlük namaz işaretleme ücretsizdir.",
                ),
              ],
              const SizedBox(height: 12),
              for (final p in perks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(p.$1, size: 36, color: cs.secondary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.$2, style: t.titleLarge),
                            Text(p.$3, style: t.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (store.isPremium)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded, size: 32),
                  label: const Text('Tamam'),
                )
              else ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(80),
                    backgroundColor: cs.secondary,
                    foregroundColor: cs.onSecondary,
                    textStyle: t.headlineSmall,
                  ),
                  onPressed: store.busy ? null : store.buy,
                  child: store.busy
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Text(
                          store.product == null
                              ? "Pro Paketi Satın Al"
                              : "Pro Paketi Al — ${store.product!.price}",
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: store.busy ? null : store.restore,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Satın Alımı Geri Yükle'),
                ),
              ],
              if (store.message != null) ...[
                const SizedBox(height: 14),
                NoticeBox(text: store.message!),
              ],
              const SizedBox(height: 14),
              Text(
                'Ödeme Google Play üzerinden yapılır.',
                textAlign: TextAlign.center,
                style: t.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget h(String s) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Semantics(header: true, child: Text(s, style: t.titleLarge)),
    );
    Widget p(String s) => Text(s, style: t.bodyLarge);
    return Scaffold(
      appBar: AppBar(title: const Text('Hakkında')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Namaz Asistanı', style: t.headlineMedium),
            p('Sürüm 0.1.0 — geliştirme sürümü'),
            h('Namaz vakitleri'),
            p(kMethodDescription),
            h('Namaz rehberi'),
            p(
              'Rehber bir öğrenme ve eşlik aracıdır; cemaat imamının veya dinî hükmün yerine geçmez. '
              'Akışlar, okunuşlar ve ses kayıtları yetkin bir dinî danışman tarafından onaylanmadan "Taslak" olarak işaretlenir.',
            ),
            h('Gizlilik'),
            p(
              'Hesap açmanız gerekmez. Ayarlarınız, zikir sayılarınız ve konumunuz yalnızca telefonunuzda saklanır; hiçbir sunucuya gönderilmez.',
            ),
            h('Reklam'),
            p(
              'Kıble + Dua ve Profil ekranlarının en altında küçük bir reklam alanı (Google AdMob) vardır; Pro Paket ile kalkar. Vakit ekranında, zikirmatikte ve namaz rehberinde reklam gösterilmez. Reklam hizmeti cihazın reklam kimliğini kullanabilir.',
            ),
            h('Sesli dualar'),
            p(
              "Dualar Kur'ân-ı Kerîm ayetlerinden seçilmiştir. Kıraat: Hafız Mahmud Halil el-Husarî (EveryAyah.com). Arapça metin: Tanzil. Meal: Türkiye Diyanet Vakfı. Ses dosyaları uygulamanın içindedir, internetsiz çalışır. Türkçe okunuşlar henüz uzman kontrolünden geçmemiştir.",
            ),
            h('İzinler'),
            p(
              '• İnternet: reklam alanı ve Google Play satın alma için.\n'
              '• Konum: yalnızca "Konumumu Kullan" derseniz, vakit ve kıble hesabı için.\n'
              '• Bildirim: namaz rehberi sırasında "Durdur" düğmeli kalıcı bildirim için.\n'
              '• Titreşim: zikir ve rehber işaretleri için.\n'
              '• Ön plan hizmeti: ekran kararınca rehberin devam etmesi için.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: NativeBridge.instance.openAppSettings,
              icon: const Icon(Icons.settings_applications_rounded),
              label: const Text('Telefon izin ayarlarını aç'),
            ),
          ],
        ),
      ),
    );
  }
}
