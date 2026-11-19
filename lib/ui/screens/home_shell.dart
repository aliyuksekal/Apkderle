import 'package:flutter/material.dart';

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
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: go,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Ana Sayfa'),
            NavigationDestination(
                icon: Icon(Icons.radio_button_unchecked_rounded),
                selectedIcon: Icon(Icons.adjust_rounded),
                label: 'Zikirmatik'),
            NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Kıble'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
