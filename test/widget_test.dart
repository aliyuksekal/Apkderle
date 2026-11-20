import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/main.dart';
import 'package:namaz_asistani/ui/screens/zikr_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<NamazApp> app(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  return NamazApp.fromPrefs(p);
}

void main() {
  setUp(() {
    // Küçük bir telefon ekranı (360x740 dp) — taşma olmamalı.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1080,
      2220,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  testWidgets('İlk kurulum: 3 soru, sonra ana sayfa', (tester) async {
    await tester.pumpWidget(await app({}));
    expect(find.text('Mezhebiniz?'), findsOneWidget);
    await tester.tap(find.text('Şafi'));
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('Hangi sureleri biliyorsunuz?'), findsOneWidget);
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('İmam hızı nasıl olsun?'), findsOneWidget);
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('İmamla Kıl'), findsOneWidget);
    expect(find.text('Zikirmatik'), findsWidgets);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('Atla ile ilk kurulum geçilir', (tester) async {
    await tester.pumpWidget(await app({}));
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.text('İmamla Kıl'), findsOneWidget);
  });

  testWidgets('Şehir seçiliyken geri sayım ve 6 vakit görünür', (tester) async {
    await tester.pumpWidget(
      await app({'onboarding_done': true, 'city_name': 'İzmir'}),
    );
    await tester.pump();
    expect(find.textContaining('kaldı'), findsOneWidget);
    for (final v in ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      expect(find.text(v), findsOneWidget, reason: v);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Şehir seçilmediyse uyarı gösterilir', (tester) async {
    await tester.pumpWidget(await app({'onboarding_done': true}));
    expect(find.text('Namaz vakitleri için şehrinizi seçin'), findsOneWidget);
  });

  testWidgets('Zikirmatik: +1, hedefte Maşallah, koyu modda çalışır', (
    tester,
  ) async {
    await tester.pumpWidget(
      await app({'onboarding_done': true, 'theme_mode': 'dark'}),
    );
    await tester.tap(find.text('Zikirmatik').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Özel'),
      200,
      scrollable: find.descendant(
        of: find.byType(ZikrScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Özel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('+1'),
      -200,
      scrollable: find.descendant(
        of: find.byType(ZikrScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('+1'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('+1'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Maşallah!'), findsOneWidget);
    expect(find.textContaining('Bugün toplam 3 zikir'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('+1'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('Premium yoksa İmamla Kıl satın alma ekranına götürür', (
    tester,
  ) async {
    await tester.pumpWidget(await app({'onboarding_done': true}));
    expect(find.textContaining('Pro — hafız sesiyle'), findsOneWidget);
    await tester.tap(find.text('İmamla Kıl'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pro pakete dahildir'), findsOneWidget);
    expect(find.text('Sabah Farzı'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Satın Alımı Geri Yükle'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Satın Alımı Geri Yükle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('İmamla Kıl → namaz seçimi → hazırlık ekranı', (tester) async {
    await tester.pumpWidget(
      await app({'onboarding_done': true, 'premium_owned': true}),
    );
    await tester.tap(find.text('İmamla Kıl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sabah Farzı'));
    await tester.pumpAndSettle();
    expect(find.text('Sabah Farzı — 2 rekât'), findsOneWidget);
    expect(find.textContaining('TASLAK'), findsOneWidget);
    final sc = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.textContaining('Hafız Mahmud Halil el-Husarî okur'),
      200,
      scrollable: sc,
    );
    await tester.scrollUntilVisible(find.text('Başlat'), 200, scrollable: sc);
    await tester.ensureVisible(find.text('Başlat'));
    expect(find.text('Başlat'), findsOneWidget);
  });

  testWidgets('Büyük sistem yazısında (1.3x) sekmelerde taşma yok', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final dark in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        await app({
          'onboarding_done': true,
          'city_name': 'Kahramanmaraş',
          'premium_owned': true,
          'theme_mode': dark ? 'dark' : 'light',
        }),
      );
      await tester.pumpAndSettle();
      for (final tab in ['Zikirmatik', 'Kıble', 'Profil', 'Ana Sayfa']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab dark=$dark');
      }
      await tester.dragUntilVisible(
        find.text('İmamla Kıl'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.ensureVisible(find.text('İmamla Kıl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İmamla Kıl'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Öğle Farzı'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.ensureVisible(find.text('Öğle Farzı'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Öğle Farzı'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'hazırlık dark=$dark');
    }
  });

  testWidgets('Premium kullanıcıda ve premium ekranında taşma yok', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(await app({'onboarding_done': true}));
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pro Pakete Geç'));
    await tester.pumpAndSettle();
    expect(find.text('Sanal İmam (Eller Serbest)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nine Modu açılınca sade ekran hemen gelir (Pro)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'city_name': 'İzmir',
      'premium_owned': true,
    });
    final p = await SharedPreferences.getInstance();
    final a = NamazApp.fromPrefs(p);
    await tester.pumpWidget(a);
    expect(find.text('Profil'), findsOneWidget);
    await a.settings.setNineMode(true);
    await tester.pumpAndSettle();
    expect(find.text('Profil'), findsNothing, reason: 'sekmeler gizlenir');
    expect(tester.takeException(), isNull);
  });
}
