import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Küçük alt banner. Kimlikler derleme sırasında verilir:
///   --dart-define=ADMOB_BANNER_ID=ca-app-pub-9672960376821171/XXXXXXXXXX
/// Verilmezse Google'ın test reklamı gösterilir (gelir getirmez).
class Ads {
  static const bannerId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741', // Google test
  );

  /// Testlerde ve reklam başlatılamadığında kapalı kalır.
  static bool enabled = false;

  /// Hangi sekmelerde banner görünür. Brifing gereği vakit ekranı (0),
  /// zikirmatik (1) ve namaz rehberinde reklam YOK.
  static const Set<int> tabsWithBanner = {2, 3};

  static Future<void> init() async {
    try {
      await _consent();
      await MobileAds.instance.initialize();
      enabled = true;
    } catch (_) {
      enabled = false;
    }
  }

  /// AB/İngiltere kullanıcıları için Google'ın onay formu (UMP).
  static Future<void> _consent() {
    final c = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!c.isCompleted) c.complete();
      },
      (_) {
        if (!c.isCompleted) c.complete();
      },
    );
    return c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }
}

/// Alt kısımdaki küçük reklam alanı. Yüklenemezse hiç yer kaplamaz.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (w != _width) {
      _width = w;
      _load(w);
    }
  }

  Future<void> _load(int width) async {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: Ads.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      // Yanlışlıkla dokunmayı önlemek için alt menüden ayrık.
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reklam',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: .6),
            ),
          ),
          SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
