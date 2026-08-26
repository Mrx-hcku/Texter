class AppwriteConfig {
  static const String endpoint = "https://sgp.cloud.appwrite.io/v1";
  static const String projectId = "6a8e7ddd00107e2b7857";
  static const String databaseId = "messgram_db";
  static const String bucketId = "texter_media";

  static const String usersCollection = "users";
  static const String chatsCollection = "chats";
  static const String messagesCollection = "messages";
  static const String groupsCollection = "groups";
  static const String channelsCollection = "channels";
  static const String adsCollection = "ads";
}

class UnityAdsConfig {
  // Replace with your real Unity Ads Game ID + placement IDs
  // (Unity Dashboard -> Monetization -> your project)
  static const String androidGameId = "YOUR_UNITY_ANDROID_GAME_ID";
  static const String interstitialPlacementId = "Interstitial_Android";
  static const bool testMode = true; // set false before release
}
