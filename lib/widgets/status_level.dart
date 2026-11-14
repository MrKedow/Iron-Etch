import 'dart:math' as math;

import '../l10n/localized_material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import 'app_ui.dart';

class BatteryStatusLevel {
  final String label;
  final Color color;
  final List<Color> auroraColors;

  const BatteryStatusLevel({
    required this.label,
    required this.color,
    required this.auroraColors,
  });

  static const _rest = BatteryStatusLevel(
    label: '需要休息啦',
    color: Color(0xFFEF4444),
    auroraColors: [Color(0xFFFF6B6B), Color(0xFFB91C1C)],
  );
  static const _tired = BatteryStatusLevel(
    label: '有点累',
    color: Color(0xFFF59E0B),
    auroraColors: [Color(0xFFFFC75F), Color(0xFFEA580C)],
  );
  static const _comingBack = BatteryStatusLevel(
    label: '力量在回来…',
    color: Color(0xFF3B82F6),
    auroraColors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
  );
  static const _power = BatteryStatusLevel(
    label: 'Power！！！',
    color: Color(0xFF22C55E),
    auroraColors: [Color(0xFF6EE7B7), Color(0xFF15803D)],
  );

  static BatteryStatusLevel forValue(int value) {
    if (value > 80) return _power;
    if (value >= 60) return _comingBack;
    if (value >= 30) return _tired;
    return _rest;
  }
}

class StatusLevelBadge extends StatefulWidget {
  final BatteryStatusLevel level;
  final double fontSize;

  const StatusLevelBadge({
    super.key,
    required this.level,
    this.fontSize = 10.5,
  });

  @override
  State<StatusLevelBadge> createState() => _StatusLevelBadgeState();
}

class _StatusLevelBadgeState extends State<StatusLevelBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 22,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * math.pi * 2;
            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          level.auroraColors.first.withValues(alpha: .55),
                          level.auroraColors.last.withValues(alpha: .8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -8 + math.sin(t) * 12,
                  top: -12 + math.cos(t) * 5,
                  child: _AuroraBlob(
                    color: level.auroraColors.first,
                    size: 34,
                  ),
                ),
                Positioned(
                  right: -10 + math.cos(t) * 10,
                  bottom: -14 + math.sin(t) * 5,
                  child: _AuroraBlob(
                    color: level.auroraColors.last,
                    size: 38,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .24),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      level.label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.fontSize,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AuroraBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: .9),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class BatteryLevelEditor extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double batteryHeight;
  final double height;
  final Color? pointerColor;

  const BatteryLevelEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.batteryHeight = 26,
    this.height = 54,
    this.pointerColor,
  });

  @override
  State<BatteryLevelEditor> createState() => _BatteryLevelEditorState();
}

class _BatteryLevelEditorState extends State<BatteryLevelEditor> {
  double? _dragFraction;

  void _updateBattery(double dx, double width) {
    final bodyWidth = width - 3.4;
    final fraction =
        ((dx - 1.9) / (bodyWidth - 2.8)).clamp(0.0, 1.0).toDouble();
    setState(() => _dragFraction = fraction);
    widget.onChanged((fraction * 100).round());
  }

  void _endDrag() {
    if (_dragFraction == null) return;
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bodyWidth = width - 3.4;
        final fraction =
            (_dragFraction ?? (widget.value / 100)).clamp(0.0, 1.0);
        final x = 1.9 + (bodyWidth - 2.8) * fraction;
        final maxLeft = (width - 8).clamp(0.0, width).toDouble();
        final pointerLeft = (x - 4).clamp(0.0, maxLeft).toDouble();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _updateBattery(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _updateBattery(details.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          onTapUp: (_) => _endDrag(),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: pointerLeft,
                  top: 0,
                  child: CustomPaint(
                    size: Size(8, widget.height),
                    painter: _BatteryPointerPainter(
                      color: widget.pointerColor ?? spec.primary,
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 14,
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: StatusBattery(
                    level: widget.value,
                    height: widget.batteryHeight,
                    bodyColor: spec.card,
                    outlineColor: spec.isDark
                        ? null
                        : spec.textPrimary.withValues(alpha: .42),
                    textColor: spec.isDark ? null : spec.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BatteryPointerPainter extends CustomPainter {
  final Color color;

  _BatteryPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .92));
  }

  @override
  bool shouldRepaint(covariant _BatteryPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}
