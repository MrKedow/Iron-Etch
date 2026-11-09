import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static bool enabled = true;
  static DateTime _lastFired = DateTime.fromMillisecondsSinceEpoch(0);

  static void _fire(Future<void> Function() action) {
    if (!enabled) return;
    final now = DateTime.now();
    if (now.difference(_lastFired) < const Duration(milliseconds: 45)) return;
    _lastFired = now;
    action();
  }

  static void select() => _fire(HapticFeedback.selectionClick);

  static void light() => _fire(HapticFeedback.lightImpact);

  static void medium() => _fire(HapticFeedback.mediumImpact);

  static void heavy() => _fire(HapticFeedback.heavyImpact);
}
