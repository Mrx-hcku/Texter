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
      onFailed: (error, message) {
        // Ad SDK failed to init; app should still work without ads.
      },
    );
  }

  /// Call this e.g. when a user opens a Group/Channel chat, to show a real
  /// interstitial ad occasionally (in addition to the native "Sponsored"
  /// content cards which are pulled from the Ads collection in Appwrite).
  static void showInterstitial() {
    if (!_initialized) return;
    UnityAds.showVideoAd(
      placementId: UnityAdsConfig.interstitialPlacementId,
      onComplete: (placementId) => UnityAds.load(placementId: UnityAdsConfig.interstitialPlacementId),
      onFailed: (placementId, error, message) {},
    );
  }
}
