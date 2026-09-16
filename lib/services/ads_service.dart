import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../config/app_config.dart';

class AdsService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await UnityAds.init(
      gameId: UnityAdsConfig.androidGameId,
      testMode: UnityAdsConfig.testMode,
      onComplete: () {
        _initialized = true;
        UnityAds.load(placementId: UnityAdsConfig.interstitialPlacementId);
      },
      onFailed: (error, message) {},
    );
  }

  static void showInterstitial() {
    if (!_initialized) return;
    UnityAds.showVideoAd(
      placementId: UnityAdsConfig.interstitialPlacementId,
      onComplete: (placementId) => UnityAds.load(placementId: UnityAdsConfig.interstitialPlacementId),
      onFailed: (placementId, error, message) {},
    );
  }
}
