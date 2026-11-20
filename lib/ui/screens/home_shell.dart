import 'package:flutter/material.dart';

import '../../core/ads.dart';
import '../../main.dart' show adsReady;
import '../app_scope.dart';

import 'home_screen.dart';
import 'profile_screen.dart';
import 'qibla_screen.dart';
import 'zikr_screen.dart';

/// Dört ana sekme: Ana Sayfa, Zikirmatik, Kıble, Profil.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenTab: go),
      const ZikrScreen(),
      QiblaScreen(active: index == 2),
      const ProfileScreen(),
    ];
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go(0); // Geri tuşu önce ana sayfaya döner.
      },
      child: Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([adsReady, context.premium]),
              builder: (context, _) =>
                  adsReady.value &&
                      !context.premium.isPremium &&
                      Ads.tabsWithBanner.contains(index)
                  ? const BannerSlot()
                  : const SizedBox.shrink(),
            ),
            _BottomBar(index: index, onTap: go),
          ],
        ),
      ),
    );
  }
}

/// Alt gezinme: büyük ikon + her zaman tek satıra sığan etiket.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Ana Sayfa'),
    (Icons.radio_button_unchecked_rounded, Icons.adjust_rounded, 'Zikirmatik'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Kıble'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    return Material(
      color: dark ? cs.surfaceContainer : cs.surfaceContainerHigh,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 84,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: _items[i].$3,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: i == index
                                    ? cs.secondary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                i == index ? _items[i].$2 : _items[i].$1,
                                size: 32,
                                color: i == index
                                    ? cs.onSecondary
                                    : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _items[i].$3,
                                maxLines: 1,
                                style: Theme.of(context).textTheme.labelMedium!
                                    .copyWith(
                                      fontWeight: i == index
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
