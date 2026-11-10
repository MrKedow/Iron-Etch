import 'dart:async';

import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static const MethodChannel _channel =
      MethodChannel('com.mrkedow.ironetch/haptics');

  static bool enabled = true;
  static DateTime _lastFired = DateTime.fromMillisecondsSinceEpoch(0);

  static void _fire(String method) {
    if (!enabled) return;
    final now = DateTime.now();
    if (now.difference(_lastFired) < const Duration(milliseconds: 45)) return;
    _lastFired = now;
    unawaited(
      _channel.invokeMethod<void>(method).catchError((Object _) {
        _fallback(method);
      }),
    );
  }

  static void _fallback(String method) {
    switch (method) {
      case 'select':
        HapticFeedback.selectionClick();
      case 'medium':
        HapticFeedback.mediumImpact();
      case 'heavy':
        HapticFeedback.heavyImpact();
      default:
        HapticFeedback.lightImpact();
    }
  }

  static void select() => _fire('select');

  static void light() => _fire('light');

  static void medium() => _fire('medium');

  static void heavy() => _fire('heavy');
}
