import 'package:flutter/services.dart';

class LiveUpdateChannel {
  static const MethodChannel _channel = MethodChannel('com.monenta.app/live_updates');

  static Future<void> show({
    required String title,
    required String text,
    String? shortText,
    required int whenTime,
    required bool useChronometer,
    required bool isCountdown,
    bool isReservation = false,
    int durationSeconds = 0,
    bool isTaskCountdown = true,
    String category = 'stopwatch',
  }) async {
    try {
      await _channel.invokeMethod('showLiveUpdate', {
        'title': title,
        'text': text,
        'shortText': shortText,
        'whenTime': whenTime,
        'useChronometer': useChronometer,
        'isCountdown': isCountdown,
        'isReservation': isReservation,
        'durationSeconds': durationSeconds,
        'isTaskCountdown': isTaskCountdown,
        'category': category,
      });
    } on PlatformException catch (_) {}
  }

  static Future<void> dismiss() async {
    try {
      await _channel.invokeMethod('dismissLiveUpdate');
    } on PlatformException catch (_) {}
  }
}