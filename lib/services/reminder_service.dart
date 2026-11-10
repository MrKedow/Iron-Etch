import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ReminderService {
  const ReminderService._();

  static const MethodChannel _channel =
      MethodChannel('com.mrkedow.ironetch/reminders');

  static Future<bool> requestPermission() async {
    final current = await Permission.notification.status;
    if (current.isGranted || current.isLimited) return true;
    final result = await Permission.notification.request();
    return result.isGranted || result.isLimited;
  }

  static Future<void> schedule(String time) async {
    try {
      await _channel.invokeMethod<void>('schedule', {'time': time});
    } catch (_) {}
  }

  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  static Future<void> sync({
    required bool enabled,
    required String time,
  }) async {
    if (enabled) {
      await schedule(time);
    } else {
      await cancel();
    }
  }
}
