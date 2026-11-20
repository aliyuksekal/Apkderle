import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/place.dart';
import '../../core/prayer_times.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets.dart';
import 'city_picker_screen.dart';
import 'guide_screens.dart';
import 'profile_screen.dart' show PremiumScreen;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final void Function(int tab) onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Geri sayımı her 15 saniyede tazele (dakika hassasiyeti yeterli).
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pickCity() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const CityPickerScreen()));

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final place = placeFromSettings(settings);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Header(
                cityName: place?.name ?? 'Şehir seçin',
                onCity: _pickCity,
                onSettings: () => widget.onOpenTab(3),
              ),
              const SizedBox(height: 8),
              if (place == null)
                _NoCityCard(onPick: _pickCity)
              else
                _TimesSection(place: place),
              const SizedBox(height: 14),
              ListenableBuilder(
                listenable: context.premium,
                builder: (context, _) {
                  final owned = context.premium.isPremium;
                  return BigActionButton(
                    icon: owned ? Icons.mosque_rounded : Icons.lock_rounded,
                    label: 'İmamla Kıl',
                    subtitle: owned
                        ? 'Hafız sesiyle namaz kıldır'
                        : 'Premium — hafız sesiyle sanal imam',
                    gold: true,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => owned
                            ? const GuideSelectScreen()
                            : const PremiumScreen(fromGuide: true),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.adjust_rounded,
                      label: 'Zikirmatik',
                      onTap: () => widget.onOpenTab(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.explore_rounded,
                      label: 'Kıble + Dua',
                      onTap: () => widget.onOpenTab(2),
                    ),
                  ),
                ],
              ),
              if (place != null) _MethodInfo(place: place),
            ],
          ),
        );
      },
    );
  }
}

class _MethodInfo extends StatelessWidget {
  const _MethodInfo({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Vakitler nasıl hesaplanıyor?'),
                content: Text(
                  '$kMethodDescription\n\nKonum: ${place.name} '
                  '(${place.lat.toStringAsFixed(2)}, ${place.lng.toStringAsFixed(2)})',
                  style: Theme.of(c).textTheme.bodyLarge,
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Tamam'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('Hesaplama yöntemi'),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.cityName,
    required this.onCity,
    required this.onSettings,
  });

  final String cityName;
  final VoidCallback onCity;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Şehir: $cityName. Değiştirmek için dokunun.',
            excludeSemantics: true,
            child: InkWell(
              onTap: onCity,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 32),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        cityName,
                        style: t.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onSettings,
          iconSize: 34,
          tooltip: 'Ayarlar',
          icon: const Icon(Icons.settings_rounded),
          constraints: const BoxConstraints(minWidth: 60, minHeight: 60),
        ),
      ],
    );
  }
}

class _NoCityCard extends StatelessWidget {
  const _NoCityCard({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Namaz vakitleri için şehrinizi seçin',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.location_city_rounded, size: 30),
              label: const Text('Şehir Seç'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimesSection extends StatelessWidget {
  const _TimesSection({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    final now = place.nowLocal();
    final today = PrayerTimes.calculate(
      latitude: place.lat,
      longitude: place.lng,
      date: now,
      utcOffset: place.utcOffset,
    );
    final tomorrowDate = now.add(const Duration(days: 1));
    final tomorrow = PrayerTimes.calculate(
      latitude: place.lat,
      longitude: place.lng,
      date: tomorrowDate,
      utcOffset: place.utcOffset,
    );
    final next = findNextPrayer(
      today: today,
      tomorrow: tomorrow,
      nowLocal: now,
    );
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Ana kart: "İzmir — İkindi'ye 1 sa 12 dk kaldı"
        Semantics(
          liveRegion: true,
          label:
              '${place.name}. ${next.name.dative} ${formatRemaining(next.remaining)} kaldı. Vakit ${hhmm(next.time)}.',
          excludeSemantics: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: dark ? Palette.nightCard : Palette.cream,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: cs.secondary, width: 2),
            ),
            child: Column(
              children: [
                Text(place.name, style: t.headlineSmall),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(next.name.dative, style: t.headlineLarge),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${formatRemaining(next.remaining)} kaldı',
                    style: t.displaySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 560 ? 6 : 3;
            const gap = 8.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final p in PrayerName.values)
                  SizedBox(
                    width: w,
                    child: _TimeTile(
                      name: p,
                      time: today[p],
                      highlighted:
                          p == next.name && next.time.day == today[p].day,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.name,
    required this.time,
    required this.highlighted,
  });

  final PrayerName name;
  final DateTime time;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fg = highlighted ? cs.onPrimary : cs.onSurface;
    final icon = switch (name) {
      PrayerName.imsak => Icons.nightlight_round,
      PrayerName.gunes => Icons.wb_twilight_rounded,
      PrayerName.ogle => Icons.wb_sunny_rounded,
      PrayerName.ikindi => Icons.wb_sunny_outlined,
      PrayerName.aksam => Icons.wb_twilight_rounded,
      PrayerName.yatsi => Icons.bedtime_rounded,
    };
    return Semantics(
      label:
          '${name.label} ${hhmm(time)}${name.isPrayer ? '' : ', güneş doğuşu, namaz vakti değildir'}${highlighted ? ', sıradaki vakit' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: highlighted ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: highlighted
              ? Border.all(color: cs.secondary, width: 3)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: highlighted ? cs.secondary : cs.tertiary,
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(name.label, style: t.titleSmall!.copyWith(color: fg)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hhmm(time),
                style: t.headlineSmall!.copyWith(color: fg),
              ),
            ),
            if (!name.isPrayer)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('doğuş', style: t.labelSmall!.copyWith(color: fg)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: cs.secondary),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(color: cs.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
