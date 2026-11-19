# Namaz Asistanı

Yaşlı dostu, Türkçe, Android öncelikli namaz asistanı (Flutter). **Aç, gör, kolayca kullan.**

- **Ana Sayfa** — sıradaki vakte geri sayım ("İzmir — İkindi'ye 1 sa 12 dk kaldı") ve İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı. Vakitler internetsiz, cihazda hesaplanır.
- **Zikirmatik** — dev +1 alanı, hedef (33/99/100/özel), "Maşallah!" + özel titreşim, geri al, onaylı sıfırla, günlük toplam ve 7 günlük geçmiş.
- **Kıble + Dua** — pusula (manyetik sapma düzeltmeli), kalibrasyon uyarısı, pusulası olmayan telefonda derece bilgisi; dua listesi (içerik doğrulama bekliyor).
- **Profil / Ayarlar** — şehir, büyük yazı (varsayılan açık), görünüm (açık/koyu/telefona göre), okuma hızı, titreşim + deneme, sesli geri bildirim, ekran kararsa devam, mezhep ve sureler, Premium (yakında), hakkında.
- **İlk kurulum** — yalnızca 3 soru (mezhep, bilinen sureler, imam hızı), atlanabilir.
- **İmamla Kıl (eller serbest rehber)** — namaz seç → tek hazırlık ekranı → Başlat. Dokunmadan ilerler, ekran kararsa da ön plan hizmetiyle sürer, bildirimde **DURDUR** düğmesi vardır. Titreşim dili: 1 kısa rükû, 2 kısa secde, 1 uzun oturma/kalkma, 3 uzun bitti.

Hesap yok, reklam yok, konum ve veriler yalnızca telefonda.

## Telefona kurma

Her `main` gönderiminde GitHub Actions uygulamayı derler. APK'yı telefondan indirmek için:
**Releases → "son-surum" → `NamazAsistani.apk`**. (Play Console için `NamazAsistani.aab` da aynı yerde.)

Gerçek imza anahtarıyla imzalamak için depo ayarlarına şu gizli değişkenleri ekleyin:
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Yoksa test (debug) anahtarı kullanılır — bu sürüm Play'e yüklenemez.

## Geliştirme

```bash
flutter pub get
flutter analyze
flutter test                      # 32 test: vakit, kıble, zikir, ayarlar, akış, ekranlar
flutter run                       # bağlı telefonda çalıştır
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release
```

Flutter 3.50 (stable), paket adı `com.benim.namazasistani`, R8 küçültme açık, ekran yönü ve yeniden boyutlandırma kısıtı yok (büyük ekran uyumlu).

## Yapı

```
lib/core/       vakit hesabı, 81 il, kıble, zikir sayacı, ayarlar, titreşim dili,
                rehber akış üretici ve zamanlayıcı, Android köprüsü
lib/ui/         tema (zümrüt / krem / altın, koyu mod), ekranlar, ortak bileşenler
content/        doğrulanacak dinî içerik: duas.json, flows/hanefi.json, flows/safii.json
android/.../    MainActivity.kt (titreşim, ses, pusula), GuideService.kt (ön plan hizmeti)
docs/brief/     ürün brifingi ve tasarım konsepti
```

## Namaz vakitleri

Diyanet açıları (İmsak 18°, Yatsı 17°, İkindi asr-ı evvel) ve Diyanet temkin düzeltmeleri (Güneş −7, Öğle +5, İkindi +4, Akşam +7 dk). Türkiye için sabit UTC+3. Testlerde Diyanet takvimiyle (19.08.2026, Bandırma ve Nazilli) karşılaştırıldı: farklar 0–2 dakika. Arayüzde yöntem ve bu fark açıkça yazılır.

## Bilinen kısıtlar / tamamlanmamış işler

- **Dinî içerik yok, bilerek:** dua metinleri, okunuşları, anlamları ve tüm ses kayıtları boş. `content/README.md` şemayı ve yapılacaklar listesini içerir. Uygulama boş içeriği "doğrulama bekliyor" olarak gösterir; uydurma metin ya da sahte ses üretmez.
- **Rehber akışları TASLAK:** Hanefi ve Şafi akışları (sıralama, süreler, kunut, zamm-ı sure seçimi) yapı göstermek içindir; yetkin dinî danışman onayı olmadan yayımlanmamalı. Başlatmadan önce kullanıcıya "Taslak" uyarısı gösterilir.
- **Ses oynatıcı henüz bağlı değil:** içerikte `audio` alanı dolunca oynatılacak nokta hazır (`GuideStep.audio`, `Dua.audio`); doğrulanmış kayıtlar gelince bir ses paketi eklenmeli.
- **Premium:** yalnızca tanıtım sayfası ("Yakında"); satın alma bağlı değil. Temel işlevler hiçbir zaman kilitlenmez.
- **Ön plan hizmeti türü `mediaPlayback`:** ses kayıtları eklendiğinde amaca uygun hâle gelir; Play Console'da ön plan hizmeti beyanı gerekir.
- Bazı üreticiler (Xiaomi, Huawei, Oppo…) pil tasarrufunda arka plan işlerini kesebilir; gerçek cihaz testi gerekir.
- Vitir ve öğlenin ilk sünneti gibi farklı yapıdaki namazlar listede yok.
- Yaşlı kullanıcılarla gerçek kullanılabilirlik testi yapılmadı.

## Yayın öncesi

- Vakitlerin Diyanet takvimiyle birkaç ilde, farklı mevsimlerde karşılaştırılması.
- Kıble pusulasının gerçek cihazlarda kalibrasyonla denenmesi.
- Tüm dinî metin, ses ve akışların uzman onayı (`content/`).
- Gizlilik politikası ve Play izin beyanları (konum: yaklaşık; bildirim; ön plan hizmeti).
