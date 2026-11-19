import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/native.dart';
import '../../core/settings.dart';
import '../../core/vibration_patterns.dart';
import '../../core/zikr.dart';
import '../app_scope.dart';
import '../widgets.dart';

class ZikrScreen extends StatelessWidget {
  const ZikrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final z = context.zikr;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zikirmatik'),
        actions: [
          IconButton(
            tooltip: 'Geçmiş',
            iconSize: 32,
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => _showHistory(context, z),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: z,
        builder: (context, _) => SafeArea(child: _Body(z: z)),
      ),
    );
  }

  void _showHistory(BuildContext context, ZikrCounter z) {
    final days = z.lastDays(7);
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('Son 7 gün', style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 8),
            for (final d in days.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${names[DateTime.parse(d.key).weekday - 1]}  ${d.key.substring(8)}.${d.key.substring(5, 7)}',
                ),
                trailing: Text(
                  '${trThousands(d.value)} zikir',
                  style: Theme.of(c).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.z});
  final ZikrCounter z;

  Future<void> _tap(BuildContext context) async {
    final s = context.settingsRead;
    final view = View.of(context);
    final completed = await z.increment();
    if (completed) {
      if (s.vibrationOn) NativeBridge.instance.vibrate(Signal.zikrGoal);
      if (s.soundFeedback) NativeBridge.instance.tone('goal');
      SemanticsService.sendAnnouncement(
        view,
        'Maşallah! Hedef tamamlandı. ${z.count}',
        TextDirection.ltr,
      );
      return;
    }
    if (s.vibrationOn) NativeBridge.instance.vibrate(Signal.tap);
    if (s.soundFeedback) NativeBridge.instance.tone('tap');
    final announce = switch (s.zikrAnnounce) {
      ZikrAnnounce.everyTap => true,
      ZikrAnnounce.everyTen => z.count % 10 == 0,
      ZikrAnnounce.off => false,
    };
    if (announce) {
      SemanticsService.sendAnnouncement(view, '${z.count}', TextDirection.ltr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        final size = (c.maxWidth * 0.66).clamp(180.0, 300.0);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Zikir seçimi
            _ZikrPicker(z: z),
            const SizedBox(height: 8),
            Center(
              child: Semantics(
                label: '${z.name}, ${z.count} / ${z.target}',
                excludeSemantics: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${z.count}',
                        style: t.displaySmall!.copyWith(
                          color: cs.brightness == Brightness.dark
                              ? cs.secondary
                              : cs.tertiary,
                          fontSize: 52,
                        ),
                      ),
                      TextSpan(text: ' / ${z.target}', style: t.headlineLarge),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: z.progress,
                minHeight: 14,
                color: cs.secondary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Semantics(
                button: true,
                label: 'Artı bir. Şu an ${z.count}',
                excludeSemantics: true,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Material(
                    shape: CircleBorder(
                      side: BorderSide(color: cs.tertiary, width: 6),
                    ),
                    color: cs.secondary,
                    elevation: 6,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _tap(context),
                      child: Center(
                        child: Text(
                          '+1',
                          style: t.displaySmall!.copyWith(
                            fontSize: size * 0.32,
                            color: cs.onSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (z.goalReached)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.secondary, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: cs.secondary,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Maşallah!',
                          style: t.headlineMedium!.copyWith(
                            color: cs.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: cs.secondary, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bugün toplam ${trThousands(z.todayTotal)} zikir çektin',
                      style: t.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: z.count == 0 ? null : z.undo,
                    icon: const Icon(Icons.undo_rounded, size: 28),
                    label: const Text('Geri Al'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: z.count == 0
                        ? null
                        : () async {
                            if (await confirmDialog(
                              context,
                              title: 'Sayaç sıfırlansın mı?',
                              message:
                                  'Şu anki sayı (${z.count}) sıfırlanacak. Bugünkü toplam korunur.',
                              yes: 'Sıfırla',
                            )) {
                              await z.reset();
                            }
                          },
                    icon: const Icon(Icons.restart_alt_rounded, size: 28),
                    label: const Text('Sıfırla'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Hedef', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final n in kZikrTargets)
                  _TargetChip(
                    label: '$n',
                    selected: z.target == n,
                    onTap: () => z.setTarget(n),
                  ),
                _TargetChip(
                  label: kZikrTargets.contains(z.target)
                      ? 'Özel'
                      : 'Özel (${z.target})',
                  selected: !kZikrTargets.contains(z.target),
                  onTap: () => _customTarget(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _customTarget(BuildContext context) async {
    final ctrl = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Özel hedef'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: Theme.of(c).textTheme.headlineSmall,
          decoration: const InputDecoration(hintText: 'ör. 500'),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.trim())),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (v != null && v > 0 && v <= 100000) await z.setTarget(v);
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? cs.primary : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 60),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: selected ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZikrPicker extends StatelessWidget {
  const _ZikrPicker({required this.z});
  final ZikrCounter z;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Zikir: ${z.name}. Değiştirmek için dokunun.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (c) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final n in kZikrNames)
                    ListTile(
                      minTileHeight: 64,
                      title: Text(n),
                      trailing: n == z.name
                          ? const Icon(Icons.check_rounded, size: 30)
                          : null,
                      onTap: () => Navigator.pop(c, n),
                    ),
                ],
              ),
            ),
          );
          if (picked != null && picked != z.name && context.mounted) {
            if (z.count == 0 ||
                await confirmDialog(
                  context,
                  title: 'Zikir değişsin mi?',
                  message: 'Şu anki sayaç (${z.count}) sıfırlanacak.',
                  yes: 'Değiştir',
                )) {
              await z.setZikr(picked);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  z.name,
                  style: t.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}
