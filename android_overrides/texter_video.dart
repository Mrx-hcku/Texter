import 'package:flutter/services.dart';

/// Shrinks a video before upload (Android). Returns the new file's path, or
/// null if it could not / need not be compressed — then send the original.
class TexterVideo {
  static const MethodChannel _channel = MethodChannel('texter/video');

  static Future<String?> compress(String inputPath, {required String jobId, int maxSide = 1280}) async {
    try {
      return await _channel.invokeMethod<String>('compress', {
        'input': inputPath,
        'jobId': jobId,
        'maxSide': maxSide,
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> cancel(String jobId) async {
    try {
      await _channel.invokeMethod('cancel', {'jobId': jobId});
    } catch (_) {}
  }
}
