import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../app_scope.dart';
import '../widgets.dart';

/// İlk kurulum — yalnızca 3 soru. Atlanabilir; ayarlardan sonra değişir.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  Madhab madhab = Madhab.hanefi;
  final Set<String> surahs = {'Fatiha', 'İhlas'};
  ReadingSpeed speed = ReadingSpeed.slow;

  Future<void> _finish() => context.settings.completeOnboarding(
        madhab: madhab,
        surahs: surahs.toList(),
        speed: speed,
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titles = [
      'Mezhebiniz?',
      'Hangi sureleri biliyorsunuz?',
      'İmam hızı nasıl olsun?',
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Hoş geldiniz',
                        style: t.titleLarge, semanticsLabel: 'Hoş geldiniz'),
                  ),
                  TextButton(
                    onPressed: () => context.settings.skipOnboarding(),
                    child: const Text('Atla'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.only(right: 6, top: 8),
                        decoration: BoxDecoration(
                          color: i <= step
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('${step + 1} / 3', style: t.titleMedium),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(titles[step], style: t.headlineLarge),
                  ),
                  const SizedBox(height: 20),
                  ..._stepBody(),
                  const SizedBox(height: 16),
                  Text('Daha sonra ayarlardan değiştirebilirsiniz.',
                      style: t.bodyMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (step > 0) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => step--),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Geri'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        if (step < 2) {
                          setState(() => step++);
                        } else {
                          _finish();
                        }
                      },
                      child: Text(step < 2 ? 'Devam Et' : 'Tamam'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stepBody() {
    switch (step) {
      case 0:
        return [
          for (final m in Madhab.values) ...[
            ChoiceButton(
              label: m.label,
              selected: madhab == m,
              onTap: () => setState(() => madhab = m),
            ),
            const SizedBox(height: 12),
          ],
        ];
      case 1:
        return [
          for (final s in kSelectableSurahs)
            CheckboxListTile(
              value: surahs.contains(s),
              onChanged: s == 'Fatiha'
                  ? null
                  : (v) => setState(() => v! ? surahs.add(s) : surahs.remove(s)),
              title: Text(s),
              subtitle: s == 'Fatiha' ? const Text('Her namazda okunur') : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: const VisualDensity(vertical: 2),
            ),
        ];
      default:
        return [
          for (final s in ReadingSpeed.values) ...[
            ChoiceButton(
              label: s.label,
              subtitle: s == ReadingSpeed.slow ? 'Önerilen' : null,
              selected: speed == s,
              onTap: () => setState(() => speed = s),
            ),
            const SizedBox(height: 12),
          ],
        ];
    }
  }
}
