# content/ — Doğrulanacak dinî içerik

Bu klasördeki her şey **uygulamaya gömülür** ama hiçbiri henüz yayına hazır değildir.
Kod hiçbir dinî metni, sureyi, tilaveti ya da namaz hükmünü kendisi üretmez; hepsini buradan okur.

## Dosyalar

| Dosya | İçerik | Durum |
|---|---|---|
| `duas.json` | Dua listesi (ad, Arapça, okunuş, anlam, ses, kaynak) | Yalnızca adlar var, metinler boş |
| `flows/hanefi.json` | Hanefi namaz rehberi akış şablonu | **TASLAK** — uzman onayı yok |
| `flows/safii.json` | Şafi namaz rehberi akış şablonu | **TASLAK** — uzman onayı yok |

## Dua şeması (`duas.json`)

```json
{
  "id": "yemek",
  "title": "Yemek Duası",
  "arabic": "…",            // Arapça metin (harekeli)
  "transliteration": "…",   // Türkçe okunuş
  "meaning": "…",           // Türkçe anlam
  "audio": "content/audio/duas/yemek.mp3",
  "source": "Kaynak adı, baskı, sayfa",
  "verified": true          // yalnızca uzman kontrolünden sonra true
}
```

`verified: false` olan dua uygulamada **"İçerik doğrulama bekliyor"** etiketiyle gösterilir; metin alanı boşsa metin gösterilmez.

## Akış şeması (`flows/*.json`)

- `status`: `taslak` | `onaylandi` — onaylanmamış akış, başlatmadan önce kullanıcıya "Taslak" uyarısıyla gösterilir.
- `reviewedBy`, `reviewedAt`: onaylayan kişi/kurul ve tarih.
- `surahs`: sure adı → `{ number (mushaf sırası), seconds (yavaş tempoda süre), audio, verified }`.
- `blocks`: `opening`, `rise`, `fatiha`, `zamm`, `ruku`, `rise_from_ruku`, `kunut` (Şafi), `sujud`, `first_sitting`, `final_sitting`, `salam`, `end`.
  Her adım: `id`, `title` (ekranda görünen kısa başlık, ör. "Fatiha..."), `seconds` (Yavaş hızdaki süre), isteğe bağlı `signal` (`ruku`, `secde`, `transition`, `done`) ve `audio`.
- Okuma hızı yalnızca süreleri çarpar: Yavaş ×1.0, Normal ×0.8, Hızlı ×0.65.

## Açık işler (TODO)

- [ ] Dua metinleri, okunuşları, anlamları — güvenilir kaynaktan, kaynak bilgisiyle.
- [ ] Dua ses kayıtları (`content/audio/duas/`), lisanslı ve doğrulanmış.
- [ ] Sure/tilavet kayıtları (`content/audio/surahs/`) ve tekbir/tesbih kayıtları.
- [ ] Hanefi akışı: sıralama, Euzü-Besmele, zamm-ı sure kuralları, süreler — uzman onayı.
- [ ] Şafi akışı: iftitah, kunut, oturuşlar — uzman onayı.
- [ ] Titreşim eşlemesinin (1 kısa rükû, 2 kısa secde, 1 uzun oturma/kalkma, 3 uzun bitti) uzmanlarca ve yaşlı kullanıcılarla test edilmesi.
- [ ] Vitir, öğlenin ilk sünneti gibi farklı yapıdaki namazlar (şu an listede yok).
