import 'package:flutter/services.dart';

/// Turns a posted message notification into an Android "Bubble" notification
/// (Android 11+). Safe to call from the FCM background isolate.
class TexterBubble {
  static const MethodChannel _channel = MethodChannel('texter/bubble');

  static Future<bool> attach({
    required int id,
    required String chatId,
    required String kind,
    required String chatName,
    String? avatarPath,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('attach', {
        'id': id,
        'chatId': chatId,
        'kind': kind,
        'chatName': chatName,
        'avatarPath': avatarPath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
