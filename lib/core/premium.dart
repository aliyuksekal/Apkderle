import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium: tek seferlik satın alma (Google Play).
/// Açtıkları: İmamla Kıl (sanal imam, hafız sesiyle) + reklamsız kullanım.
///
/// Ürün kimliği Play Console > Para kazanma > Uygulama içi ürünler'de
/// aynı adla oluşturulmalıdır.
class PremiumStore extends ChangeNotifier {
  PremiumStore(this._p);

  static const productId = 'namaz_premium';
  static const _kPremium = 'premium_owned';

  final SharedPreferences _p;
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Mağaza ürünü (fiyat bilgisi için). null = henüz yüklenmedi/bulunamadı.
  ProductDetails? product;
  bool storeAvailable = false;
  bool busy = false;
  String? message;

  bool get isPremium => _p.getBool(_kPremium) ?? false;

  /// Uygulama açılışında çağrılır (testlerde çağrılmaz).
  Future<void> connect() async {
    try {
      final iap = _iap = InAppPurchase.instance;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      storeAvailable = await iap.isAvailable();
      if (storeAvailable) {
        final r = await iap.queryProductDetails({productId});
        product = r.productDetails.isEmpty ? null : r.productDetails.first;
        // Önceden satın alındıysa (yeni telefon, yeniden kurulum) geri getir.
        await iap.restorePurchases();
      }
    } catch (_) {
      storeAvailable = false;
    }
    notifyListeners();
  }

  Future<void> buy() async {
    final iap = _iap;
    final pr = product;
    if (iap == null || !storeAvailable || pr == null) {
      message =
          'Google Play mağazasına bağlanılamadı. İnternetinizi kontrol edin; uygulama Google Play\'den yüklenmiş olmalıdır.';
      notifyListeners();
      return;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: pr),
      );
    } catch (_) {
      busy = false;
      message = 'Satın alma başlatılamadı. Lütfen tekrar deneyin.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    final iap = _iap;
    if (iap == null || !storeAvailable) {
      message = 'Google Play mağazasına bağlanılamadı.';
      notifyListeners();
      return;
    }
    busy = true;
    message = null;
    notifyListeners();
    await iap.restorePurchases();
    // Geri yüklenecek satın alma yoksa akış hiçbir şey göndermeyebilir.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (busy) {
      busy = false;
      message = isPremium
          ? 'Pro Paket etkin.'
          : 'Bu Google hesabında Pro Paket satın alımı bulunamadı.';
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      if (pd.productID != productId) continue;
      switch (pd.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _p.setBool(_kPremium, true);
          busy = false;
          message = 'Pro Paket etkin. Allah razı olsun!';
        case PurchaseStatus.pending:
          message =
              'Ödeme onay bekliyor. Onaylanınca Pro Paket otomatik açılır.';
        case PurchaseStatus.error:
          busy = false;
          message = 'Ödeme tamamlanamadı. Hesabınızdan para çekilmedi.';
        case PurchaseStatus.canceled:
          busy = false;
          message = null;
      }
      if (pd.pendingCompletePurchase) {
        await _iap?.completePurchase(pd);
      }
    }
    notifyListeners();
  }

  /// Sadece testler ve geliştirme için.
  @visibleForTesting
  Future<void> debugSetPremium(bool v) async {
    await _p.setBool(_kPremium, v);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
