import 'dart:async';

import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static const MethodChannel _channel =
      MethodChannel('com.mrkedow.ironetch/haptics');

  static bool enabled = false;
  static bool vibrationEnabled = false;
  static bool motionEnabled = false;
  static DateTime _lastFired = DateTime.fromMillisecondsSinceEpoch(0);
  static int _lastPriority = -1;

  static bool get shouldVibrate => enabled && vibrationEnabled;

  static bool get shouldAnimate => enabled && motionEnabled;

  static void _fire(String method, int priority) {
    if (!shouldVibrate) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFired);
    if (elapsed < const Duration(milliseconds: 45) &&
        priority <= _lastPriority) {
      return;
    }
    _lastFired = now;
    _lastPriority = priority;
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

  static void tap() => _fire('select', 0);

  static void select() => _fire('select', 1);

  static void light() => _fire('light', 2);

  static void medium() => _fire('medium', 3);

  static void heavy() => _fire('heavy', 4);
}
