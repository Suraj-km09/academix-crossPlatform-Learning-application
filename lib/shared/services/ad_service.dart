import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  AdService._();

  static InterstitialAd? _interstitialAd;

  static const String _counterKey = 'interstitial_call_counter';
  static const int _showEveryNCalls = 5;

  static const String _bannerDefine = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: '',
  );
  static const String _interstitialDefine = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: '',
  );
  static const bool _enableAdsInDebug = bool.fromEnvironment(
    'ENABLE_ADS_IN_DEBUG',
    defaultValue: false,
  );

  static bool get _adsEnabledForCurrentBuild =>
      kReleaseMode || _enableAdsInDebug;

  static Future<void> initAds() async {
    if (!_adsEnabledForCurrentBuild) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // Silent failure by requirement.
    }
  }

  static BannerAd? loadBannerAd(String? adUnitId, {VoidCallback? onLoaded}) {
    if (!_adsEnabledForCurrentBuild) {
      return null;
    }
    final resolvedUnitId = _resolveBannerAdUnitId(adUnitId);
    if (resolvedUnitId.trim().isEmpty) {
      return null;
    }

    final ad = BannerAd(
      adUnitId: resolvedUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
        },
      ),
    );

    try {
      ad.load();
      return ad;
    } catch (_) {
      ad.dispose();
      return null;
    }
  }

  static Future<void> loadInterstitialAd(
    String? adUnitId,
    VoidCallback onLoaded,
  ) async {
    if (!_adsEnabledForCurrentBuild) {
      return;
    }
    final resolvedUnitId = _resolveInterstitialAdUnitId(adUnitId);
    if (resolvedUnitId.trim().isEmpty) {
      return;
    }

    try {
      await InterstitialAd.load(
        adUnitId: resolvedUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd?.dispose();
            _interstitialAd = ad;
            onLoaded();
          },
          onAdFailedToLoad: (_) {
            _interstitialAd = null;
          },
        ),
      );
    } catch (_) {
      _interstitialAd = null;
    }
  }

  static Future<void> showInterstitialIfReady() async {
    if (!_adsEnabledForCurrentBuild) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_counterKey) ?? 0;
      final updated = current + 1;
      await prefs.setInt(_counterKey, updated);

      if (updated % _showEveryNCalls != 0) {
        return;
      }

      final ad = _interstitialAd;
      if (ad == null) {
        return;
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          _interstitialAd = null;
        },
      );

      ad.show();
    } catch (_) {
      // Silent failure by requirement.
    }
  }

  static String _resolveBannerAdUnitId(String? adUnitId) {
    final fallback = adUnitId ?? _bannerDefine;
    if (!kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111';
      }
      if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716';
      }
      return '';
    }
    return fallback;
  }

  static String _resolveInterstitialAdUnitId(String? adUnitId) {
    final fallback = adUnitId ?? _interstitialDefine;
    if (!kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/1033173712';
      }
      if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/4411468910';
      }
      return '';
    }
    return fallback;
  }
}
