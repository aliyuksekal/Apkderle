import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads.dart';
import 'core/settings.dart';
import 'core/zikr.dart';
import 'ui/app_scope.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(NamazApp(settings: AppSettings(prefs), zikr: ZikrCounter(prefs)));
  // Reklamlar açılışı geciktirmesin: uygulama çizildikten sonra başlat.
  Ads.init().then((_) => adsReady.value = Ads.enabled);
}

/// Reklam altyapısı hazır olunca true olur.
final ValueNotifier<bool> adsReady = ValueNotifier(false);

class NamazApp extends StatelessWidget {
  const NamazApp({super.key, required this.settings, required this.zikr});

  final AppSettings settings;
  final ZikrCounter zikr;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      zikr: zikr,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Namaz Asistanı',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: settings.themeMode,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            // Büyük yazı modu: sistem yazı boyutunun üstüne %15 ekler.
            final mq = MediaQuery.of(context);
            final scale = settings.largeText ? 1.15 : 1.0;
            final sys = mq.textScaler.scale(1);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear((sys * scale).clamp(1.0, 2.2)),
              ),
              child: child!,
            );
          },
          home: settings.onboardingDone
              ? const HomeShell()
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}
