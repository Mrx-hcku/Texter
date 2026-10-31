import 'package:flutter/services.dart';

/// Turns a posted message notification into an Android "Bubble" notification
/// (Android 11+). Safe to call from the FCM background isolate.
class TexterBubble {
  static const MethodChannel _channel = MethodChannel('texter/bubble');

  /// True on Android 11+ (real notification bubbles available).
  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Removes the extra notification Firebase shows by itself (duplicate of ours).
  static Future<void> dismissFcm() async {
    try {
      await _channel.invokeMethod('dismissFcm');
    } catch (_) {}
  }

  static Future<bool> attach({
    required int id,
    required String chatId,
    required String kind,
    required String chatName,
    required String senderName,
    required String body,
    List<Map<String, Object?>> messages = const [],
    String? avatarPath,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('attach', {
        'id': id,
        'chatId': chatId,
        'kind': kind,
        'chatName': chatName,
        'senderName': senderName,
        'body': body,
        'messages': messages,
        'avatarPath': avatarPath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
