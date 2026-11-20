import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads.dart';
import 'core/family.dart';
import 'core/premium.dart';
import 'core/prayer_log.dart';
import 'core/reminders.dart';
import 'core/settings.dart';
import 'core/zikr.dart';
import 'ui/app_scope.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  platformServices = true;
  final prefs = await SharedPreferences.getInstance();
  final premium = PremiumStore(prefs);
  runApp(NamazApp.fromPrefs(prefs, premium: premium));
  premium.connect();
  // Reklamlar açılışı geciktirmesin: uygulama çizildikten sonra başlat.
  Ads.init().then((_) => adsReady.value = Ads.enabled);
}

/// Bildirim/ağ gibi platform hizmetleri yalnızca gerçek uygulamada çalışır
/// (testlerde kapalı).
bool platformServices = false;

/// Reklam altyapısı hazır olunca true olur.
final ValueNotifier<bool> adsReady = ValueNotifier(false);

class NamazApp extends StatelessWidget {
  const NamazApp({
    super.key,
    required this.settings,
    required this.zikr,
    required this.premium,
    required this.log,
    required this.reminders,
    required this.family,
  });

  factory NamazApp.fromPrefs(SharedPreferences p, {PremiumStore? premium}) {
    final log = PrayerLog(p);
    return NamazApp(
      settings: AppSettings(p),
      zikr: ZikrCounter(p),
      premium: premium ?? PremiumStore(p),
      log: log,
      reminders: ReminderSettings(p),
      family: FamilyStore(p, log),
    );
  }

  final AppSettings settings;
  final ZikrCounter zikr;
  final PremiumStore premium;
  final PrayerLog log;
  final ReminderSettings reminders;
  final FamilyStore family;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      zikr: zikr,
      premium: premium,
      log: log,
      reminders: reminders,
      family: family,
      child: ListenableBuilder(
        listenable: Listenable.merge([settings, premium]),
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
