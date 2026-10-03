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
  static const String androidGameId = "YOUR_UNITY_ANDROID_GAME_ID";
  static const String interstitialPlacementId = "Interstitial_Android";
  static const bool testMode = true;
}

class PushServerConfig {
  // Render pe deploy hone ke baad yahan apna actual URL daalo, jaise:
  // "https://texter-push.onrender.com/notify"
  static const String notifyUrl = "https://pushnotes-ir1i.onrender.com//notify";

  // Render ke "Environment" tab me jo NOTIFY_SECRET set kiya hai, wahi
  // bilkul yahan bhi daalo (dono ek jaise hone chahiye).
  static const String secret = "jbauvshvuhsgy6#6-#";
}
