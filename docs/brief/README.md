# Namaz Asistanı — Claude Geliştirme Paketi

Bu arşiv, Claude'a vererek Android öncelikli bir namaz asistanı geliştirmek için hazırlanmış ürün ve tasarım brifingidir.

## Dosyalar
- `CLAUDE_PROMPT.md` — Claude'a verilecek ana talimat.
- `PRODUCT_SPEC.md` — Ürün kapsamı ve gereksinimler.
- `SCREEN_FLOW.md` — Ekranlar ve örnek arayüz metinleri.
- `ACCESSIBILITY.md` — Yaşlı dostu tasarım kuralları.
- `tasarim/arayuz_konsept.png` — Görsel tasarım referansı.

## Claude'da nasıl kullanılır?
1. ZIP'i aç.
2. Klasörü Claude'a yükle (veya dosyaları proje çalışma alanına ekle).
3. Önce `CLAUDE_PROMPT.md` dosyasını ver.
4. Ardından diğer Markdown dosyalarını ve `tasarim/arayuz_konsept.png` görselini bağlam olarak ekle.
5. Claude'dan önce proje planını ve dosya yapısını çıkarmasını, ardından çalışan MVP'yi geliştirmesini iste.

## Önemli yayın öncesi işler
- Namaz vakitleri hesaplama kaynağı ve yöntemi doğrulanmalı.
- Kıble pusulası gerçek sensör verisi ve kalibrasyonla test edilmeli.
- Arapça metinler, okunuşlar, anlamlar ve ses kayıtları güvenilir kaynaklardan alınmalı.
- Hanefi ve Şafi namaz akışları, duraklamalar ve titreşim eşlemeleri yetkin dinî uzmanlarca gözden geçirilmeli.
- Gerçek cihazlarda ekran kilidi, arka plan ses ve titreşim test edilmeli.
- Gizlilik politikası ve gerekli Android izin açıklamaları hazırlanmalı.

Bu paket tasarım/ürün brifingidir; tek başına APK değildir. Claude'un geliştirme yapacağı kaynak proje bu brifingden oluşturulacaktır.
