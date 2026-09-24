import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../config/app_config.dart';

class AdsService {
  static bool _initialized = false;

  /// Returns false if the Unity Game ID is still the placeholder value —
  /// in that case ads are silently skipped instead of crashing the app.
  static bool get _isConfigured =>
      UnityAdsConfig.androidGameId.isNotEmpty &&
      UnityAdsConfig.androidGameId != "YOUR_UNITY_ANDROID_GAME_ID";

  static Future<void> init() async {
    if (_initialized || !_isConfigured) return;
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
    if (!_initialized || !_isConfigured) return;
    UnityAds.showVideoAd(
      placementId: UnityAdsConfig.interstitialPlacementId,
      onComplete: (placementId) => UnityAds.load(placementId: UnityAdsConfig.interstitialPlacementId),
      onFailed: (placementId, error, message) {},
    );
  }
}
