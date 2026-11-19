# CLAUDE İÇİN ANA GELİŞTİRME TALİMATI — YAŞLI DOSTU NAMAZ ASİSTANI

Sen kıdemli bir Android/Flutter geliştiricisi, ürün tasarımcısı ve erişilebilirlik uzmanısın. Bu paketteki `PRODUCT_SPEC.md`, `SCREEN_FLOW.md` ve `ACCESSIBILITY.md` dosyalarını eksiksiz oku. `tasarim/arayuz_konsept.png` görselini görsel yön olarak kullan. Ama görseldeki metinleri birebir kopyalamak zorunda değilsin; doğru Türkçe, tutarlı boşluklar ve gerçek cihazda kullanılabilir arayüz önceliklidir.

## Ürün hedefi
Türkçe konuşan, özellikle ileri yaştaki kullanıcıların namaz vakitlerini hızlıca görmesini, zikir çekmesini, kıbleyi bulmasını ve isteğe bağlı sesli/titreşimli namaz rehberini kullanmasını sağlayan sade bir Android uygulaması geliştir. Uygulamanın temel vaadi: **Aç, gör, kolayca kullan.** Kullanıcıyı küçük yazılar, karmaşık menüler, gereksiz kayıt ekranları veya reklamlarla yorma.

## Önce yap, sonra raporla
1. Çalışma klasörünü incele. Var olan proje varsa yapısını ve teknolojisini koru; yoksa Android öncelikli Flutter projesi oluştur.
2. Uygulamayı çalışır bir MVP olarak geliştir. Yalnızca ekran çizip bırakma: gezinme, sayaç, ayarlar, yerel kayıt, ses/titreşim kontrolleri ve örnek akış gerçekten çalışsın.
3. Tasarımı responsive yap; küçük Android ekranlarında da taşma olmasın.
4. Tüm kullanıcı arayüzü Türkçe olsun.
5. Kodda sahte namaz vakti veya sahte kıble doğruluğu varmış gibi davranma. Gerçek servis/hesaplama henüz bağlanmadıysa açıkça “Örnek veri” / “Konum veya pusula izni gerekli” durumunu göster.
6. Gerçek dini metinleri, sureleri ve tilavet kayıtlarını uydurma. Kaynak ve doğrulama gerektiren içerikleri `content/` altında açıkça işaretlenmiş placeholder olarak bırak; içerik şeması ve entegrasyon noktasını hazırla. Yayına çıkmadan önce yetkin dinî danışman/kurul kontrolü gerektiğini README'de belirt.
7. Her ana özellik için test ekle; en azından sayaç, hedef tamamlama, ayarların saklanması, ekran akışı ve titreşim desenlerinin eşlemesi test edilsin.
8. En sonunda kurulum, çalıştırma, test ve APK üretme adımlarını README'ye yaz; tamamlanmayan entegrasyonları dürüstçe listele.

## Tasarım dili
- Ana renkler: koyu zümrüt yeşili, açık sıcak krem, yumuşak altın.
- Büyük ve kalın Türkçe yazılar; yüksek kontrast; bol boşluk.
- Dokunma alanları en az 56–64 dp; ana eylem butonları mümkünse 68–80 dp.
- İnce çizgili, belirsiz ikonlardan kaçın. İkon + metin kullan.
- Dört ana gezinme sekmesi: Ana Sayfa, Zikirmatik, Kıble, Profil.
- Ana sayfa açılışında vakit bilgisi hemen görünür olsun. Gereksiz açılış animasyonu yok; hızlı açılış hedefle.
- Yaşlı kullanıcılar için “Büyük Yazı / Kolay Kullanım” varsayılanı açık olsun.
- Metin boyutu, kontrast ve sesli geri bildirim ayarları kolay bulunur olsun.

## Ekranlar ve işlevler
### 1. Ana Sayfa — Vakitler
- En üstte şehir seçimi.
- Büyük metin: “İzmir — İkindi'ye 1 sa 12 dk kaldı” biçiminde, fakat gerçek vakit ve geri sayımdan dinamik üret.
- Altında İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı vakitlerini doğru sırada göster. Kullanıcının ilk taslağında beş vakit denmiş olsa da Güneş de ayrı bilgi olarak gösterilebilir; namaz vakti olarak sayılmamalıdır.
- Sıradaki vakit kartı belirgin olsun.
- Büyük “İmamla Kıl” / “Namaz Rehberini Başlat” butonu.
- Zikirmatik ve Kıble + Dua kısa yolları.
- İlk ekranda kullanıcıyı hesap açmaya zorlama.
- Açılış hedefi hızlı; animasyon 0–0.5 saniyeyi geçmesin.

### 2. Zikirmatik
- Ekranın merkezinde çok büyük +1 dokunma alanı.
- Üstte zikir adı ve sayaç: “Sübhanallah — 33 / 99”.
- Her dokunuşta sayaç +1; isteğe bağlı hafif titreşim ve açılıp kapatılabilir ses.
- Hedef tamamlanınca “Maşallah” bildirimi, kısa özel titreşim ve isteğe bağlı ses.
- Hedef 33/99/100 veya özel sayı seçilebilsin.
- Geri al ve sıfırla kontrolleri yanlış dokunmayı önleyecek şekilde ayrı ve küçük olmayan butonlar olsun; sıfırlama onay istesin.
- “Bugün toplam 1.240 zikir çektin” gibi günlük toplam yerel olarak saklansın. Rakam gerçek sayaçtan gelsin; örnek veri gerçekmiş gibi gösterilmesin.
- Ekran okuyucu her dokunuşta sayıyı duyurabilsin; arka arkaya gereksiz konuşmayı önlemek için ayarlanabilir olsun.

### 3. Kıble + Dua
- Pusula/cihaz sensörüyle kıble yönü; sensör kalibrasyonu ve izin durumu açıkça gösterilsin.
- Pusula yoksa veya izin verilmemişse dereceyi kesinmiş gibi gösterme; harita/manuel yön alternatifi veya açıklama sun.
- “Telefonu düz tutun ve kalibrasyon için sekiz çizin” gibi kısa, sesli de okunabilen yardım.
- En çok okunan dualar listesi: Nazar duası, Yemek duası, Sınava girerken okunacak dua, Hastalık duası, Yolculuk duası vb.
- Her dua için okunabilir Arapça metin, Türkçe okunuş, anlam ve sesli dinleme alanı. Doğrulanmamış içerik yayınlama; kaynak alanı ve onay durumu tut.
- Sesli dinleme kontrolleri büyük olsun.

### 4. Profil / Ayarlar
- Şehir seçimi.
- Premium sayfası.
- Büyük yazı / kolay kullanım (varsayılan açık).
- Okuma hızı: Yavaş (varsayılan), Normal, Hızlı.
- Titreşim: Açık/Kapalı ve desenleri deneme.
- Sesli geri bildirim: Açık/Kapalı.
- Ekran kararsa ses devam etsin: Açık/Kapalı (varsayılan açık, izin/Android kısıtları açıklanmalı).
- Uygulama hakkında, gizlilik ve izinler.
- İlk kurulum tercihleri sonradan değiştirilebilir.

### 5. Sanal İmam / Eller Serbest Namaz Rehberi
- Ana sayfada büyük “İmamla Kıl” butonuna basılır; kullanıcı namazı seçer (ör. Sabah farzı 2 rekat).
- Başlamadan önce tek bir kısa hazırlık ekranı: telefonun seccade yanında veya güvenli bir yerde durması, ses seviyesinin ayarlanması, titreşim testi. Kullanıcı “Başlat”a bir kez basar.
- Başladıktan sonra rehber boyunca ekrana dokunma gerektirmeyen bir akış. Telefon kilitlense/ekran kararsa da ses ve titreşim sürsün; Android'de gerekli foreground service, bildirim ve izinleri doğru uygula. İşletim sistemi kısıtlarını dürüstçe ele al.
- Rehber, kullanıcının namaz sırasında dinleyebileceği sakin, yavaş, kesintisiz ve sade bir ses akışı sağlar. “Şimdi şunu yapıyoruz” gibi öğretici açıklama cümleleri kullanma. Kullanıcının istediği dil biçimi:
  - “Sübhaneke...”
  - “Fatiha...”
  - “İhlas...”
  - Hareket geçişlerinde uygun tekbir ve titreşim.
- Sesli içerik yalnızca doğrulanmış kayıt/varlık üzerinden çalışmalı. İlk prototipte ses dosyaları yoksa sessizce sahte ses üretme; “Ses içerikleri henüz eklenmedi” şeklinde geliştirme durumu göster.
- Sure seçimi: ilk kurulumda kullanıcının bildiği sureler işaretlenir. Sistem yalnızca kullanıcının seçtiği ve ilgili namaz akışında kullanılmasına izin verilen sureler arasından seçim yapar. Varsayılan örnek İhlas olabilir; ama gerçek dini akış, mezhep farklılıkları ve kıraat hükümleri yetkin danışman tarafından doğrulanmadan kesin hüküm olarak kodlanmasın.
- Mezhep seçimi: Hanefi / Şafi. Seçim akış şablonunu etkiler; farklılıklar doğrulanmış konfigürasyon dosyalarında tutulur, kod içine gelişigüzel gömülmez.
- Okuma hızı: Yavaş varsayılan; Normal; Hızlı. Hız yalnızca uygun duraklama/tempo parametrelerini değiştirir, tilavetin telaffuzunu bozmaz.
- Titreşim dili (kullanıcının önerdiği başlangıç eşlemesi):
  - 1 kısa titreşim = rükûya geçiş işareti
  - 2 kısa titreşim = secdeye geçiş işareti
  - 1 uzun titreşim = oturma/kalkma gibi yapılandırılmış geçiş işareti
  - 3 uzun titreşim = namaz rehberi tamamlandı
  - Titreşim desenleri ayarlardan test edilebilir; cihaz desteklemiyorsa sesli işaret alternatifi sun.
- Rehberin sonunda 3 uzun titreşim, “Namaz bitti” ve “Allah kabul etsin” mesajı.
- Kullanıcı istediğinde acil durdurma için bildirimden veya ekrandan erişilebilir durdurma kontrolü olmalı. “Hiç dokunma” normal akış kuralıdır; güvenlik/durdurma yolu mutlaka bulunmalıdır.
- Bu özellik gerçek cemaat imamı veya dinî hüküm yerine geçiyor gibi pazarlanmamalı. “Namaz rehberi / öğrenme ve eşlik aracı” şeklinde konumlandırılmalı. Yayın öncesi her mezhep için namaz akışı, ses metni, duraklama ve hareket eşlemesi uzmanlarca gözden geçirilmeli.

## İlk kurulum — sadece 3 soru
1. “Mezhebiniz?” Hanefi / Şafi.
2. “Hangi sureleri biliyorsunuz?” Fatiha, İhlas, Kevser, Nas, Felak vb. çoklu seçim.
3. “Rehberin okuma hızı?” Yavaş / Normal / Hızlı. Varsayılan Yavaş.
- Atla seçeneği olsun; daha sonra ayarlardan tamamlanabilsin.
- İlk kurulum yalnızca ilk açılışta gösterilsin; tekrar tekrar sorma.

## Premium yaklaşımı
- Temel namaz vakitleri, zikirmatik, kıble ve temel rehber işlevleri ücretsiz ve reklamsız/rahatsız etmeyen şekilde kullanılabilir olmalı.
- Premium; ek tema, ek dua sesleri, gelişmiş istatistik, ek kişiselleştirme gibi ikincil özellikler sunabilir.
- Namaz esnasında, vakit ekranında veya zikrin ortasında reklam gösterme. Premium satın alma zorunluluğu ile ibadetin temel işlevlerini kilitleme.

## Teknik beklentiler
- Android öncelikli; proje yoksa Flutter + temiz, modüler mimari.
- Yerel tercih/sayaç saklama; internet olmadan temel ekranlar ve kayıtlı içerikler çalışsın.
- Bildirim/foreground audio service; Android sürüm ve izin gereksinimlerini kontrol et.
- Ses, titreşim, konum ve pusula izinlerini yalnızca gerektiği anda açıkla ve iste.
- Konum seçimi manuel şehir listesiyle de yapılabilsin; kullanıcı konumu zorunlu olmasın.
- Namaz vakitleri için hesaplama yöntemi ve kaynak şeffaf biçimde gösterilsin; şehir/saat dilimi/yaz saati konuları doğru ele alınsın.
- Kıble için sensör verisi ve kalibrasyon durumu kontrol edilsin.
- Hassas konum verisini gereksiz yere sunucuya gönderme; mümkünse cihazda işle.
- Hata durumlarında yaşlı kullanıcının anlayacağı Türkçe mesajlar göster.

## Teslimat
- Çalışır proje kaynak kodu.
- Uygulama ekranları ve gezinme.
- README: kurulum, çalıştırma, test, APK alma.
- Testler.
- `content/` klasöründe doğrulanacak dinî metin/ses içerikleri için şema ve açık TODO listesi.
- Bilinen kısıtlar ve tamamlanmamış entegrasyonlar listesi.
- Son yanıtta yapılanları, test sonuçlarını, APK üretmek için komutları ve eksik kalan gerçek servis/ses/dinî doğrulama işlerini maddeler halinde raporla.
