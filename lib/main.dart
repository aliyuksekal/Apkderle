import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads.dart';
import 'core/audio.dart';
import 'core/premium.dart';
import 'core/prayer_log.dart';
import 'core/reminders.dart';
import 'core/settings.dart';
import 'core/zikr.dart';
import 'ui/app_scope.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/tap_reader.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  platformServices = true;
  // Ekran çizilirken hata olursa gri/boş ekran yerine okunabilir bir mesaj.
  ErrorWidget.builder = (d) =>
      _ErrorBox('${d.exceptionAsString()}\n${d.stack}');
  final PremiumStore premium;
  try {
    final prefs = await SharedPreferences.getInstance();
    premium = PremiumStore(prefs);
    runApp(NamazApp.fromPrefs(prefs, premium: premium));
  } catch (e, st) {
    runApp(MaterialApp(home: Scaffold(body: _ErrorBox('$e\n$st'))));
    return;
  }
  premium.connect();
  AssetAudio.instance.problems.listen(
    (m) => messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(m, style: const TextStyle(fontSize: 20)),
          duration: const Duration(seconds: 6),
        ),
      ),
  );
  // Reklamlar açılışı geciktirmesin: uygulama çizildikten sonra başlat.
  Ads.init().then((_) => adsReady.value = Ads.enabled);
}

/// Bildirim/ağ gibi platform hizmetleri yalnızca gerçek uygulamada çalışır
/// (testlerde kapalı).
bool platformServices = false;

/// Ses sorunlarını (sessiz telefon, çalınamayan dosya) her ekranda gösterir.
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

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
  });

  factory NamazApp.fromPrefs(SharedPreferences p, {PremiumStore? premium}) {
    final log = PrayerLog(p);
    return NamazApp(
      settings: AppSettings(p),
      zikr: ZikrCounter(p),
      premium: premium ?? PremiumStore(p),
      log: log,
      reminders: ReminderSettings(p),
    );
  }

  final AppSettings settings;
  final ZikrCounter zikr;
  final PremiumStore premium;
  final PrayerLog log;
  final ReminderSettings reminders;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      zikr: zikr,
      premium: premium,
      log: log,
      reminders: reminders,
      child: ListenableBuilder(
        listenable: Listenable.merge([settings, premium]),
        builder: (context, _) => MaterialApp(
          title: 'Namaz Asistanı',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: messengerKey,
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
              // Büyüklerimiz Modu: dokunulan her şey sesli okunur.
              child: ListenableBuilder(
                listenable: premium,
                builder: (context, _) => TapReader(
                  enabled: settings.nineMode && premium.isPremium,
                  child: child!,
                ),
              ),
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

/// Hata mesajı kutusu: kullanıcı ekran görüntüsü alıp gönderebilsin.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      color: const Color(0xFFFBF3E1),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Text(
          'Bir hata oluştu. Lütfen bu ekranın görüntüsünü geliştiriciye gönderin.\n\n$text',
          style: const TextStyle(color: Color(0xFF13241D), fontSize: 14),
        ),
      ),
    ),
  );
}
