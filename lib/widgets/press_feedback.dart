import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_haptics.dart';

/// Applies the shared press animation to any tappable child.
///
/// The listener only observes pointer events, so child buttons, ink wells and
/// gesture detectors keep working normally.
class AppPressFeedback extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double pressedScale;
  final double dimOpacity;
  final Duration pressDelay;

  const AppPressFeedback({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.pressedScale = .972,
    this.dimOpacity = .075,
    this.pressDelay = const Duration(milliseconds: 35),
  });

  @override
  State<AppPressFeedback> createState() => _AppPressFeedbackState();
}

class _AppPressFeedbackState extends State<AppPressFeedback> {
  bool _pressed = false;
  Timer? _pressTimer;
  int? _pointer;
  Offset _downPosition = Offset.zero;
  bool _moved = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (!AppHaptics.shouldAnimate || _pointer != null) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _moved = false;
    _pressTimer?.cancel();
    _pressTimer = Timer(widget.pressDelay, () {
      if (!mounted || _pointer != event.pointer || _moved) return;
      setState(() => _pressed = true);
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downPosition).distance > 10) {
      _moved = true;
      _cancelPress();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _finishPress();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _finishPress();
  }

  void _cancelPress() {
    _pressTimer?.cancel();
    if (!_pressed) return;
    if (mounted) setState(() => _pressed = false);
  }

  void _finishPress() {
    _pointer = null;
    _cancelPress();
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _pressed && AppHaptics.shouldAnimate;
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedScale(
        scale: active ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: active ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedSlide(
          offset: active ? const Offset(0, .012) : Offset.zero,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Stack(
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: const Duration(milliseconds: 110),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: widget.dimOpacity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fires the shared light haptic for real taps anywhere in the app while
/// ignoring scrolls and long drags.
class GlobalTapFeedback extends StatefulWidget {
  final Widget child;

  const GlobalTapFeedback({super.key, required this.child});

  @override
  State<GlobalTapFeedback> createState() => _GlobalTapFeedbackState();
}

class _GlobalTapFeedbackState extends State<GlobalTapFeedback> {
  int? _pointer;
  Offset _downPosition = Offset.zero;
  DateTime? _downAt;
  bool _moved = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _downAt = DateTime.now();
    _moved = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downPosition).distance > 14) _moved = true;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final elapsed = DateTime.now().difference(
      _downAt ?? DateTime.now(),
    );
    if (!_moved && elapsed < const Duration(milliseconds: 650)) {
      AppHaptics.tap();
    }
    _reset();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _reset();
  }

  void _reset() {
    _pointer = null;
    _downAt = null;
    _moved = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}
