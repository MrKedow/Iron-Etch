import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_providers.dart';
import 'app_ui.dart';

const List<List<Color>> statusTones = [
  [Color(0xFFE4B363), Color(0xFFB45309)],
  [Color(0xFF4FD1C5), Color(0xFF2563EB)],
  [Color(0xFF8B5CF6), Color(0xFFEC4899)],
  [Color(0xFFF97316), Color(0xFFDC2626)],
  [Color(0xFF22C55E), Color(0xFF0F766E)],
  [Color(0xFF94A3B8), Color(0xFF334155)],
];

const List<String> statusMotionNames = ['极光流动', '微光扫过', '星尘漂浮'];

class StatusBanner extends StatefulWidget {
  final int streakDays;
  final int streakHours;
  final int streakMinutes;

  const StatusBanner({
    super.key,
    required this.streakDays,
    required this.streakHours,
    required this.streakMinutes,
  });

  @override
  State<StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final workout = context.watch<WorkoutProvider>();
    final spec = context.watch<ThemeProvider>().currentSpec;
    final tone = statusTones[settings.statusTone % statusTones.length];
    final hasImage = settings.statusImagePath != null &&
        File(settings.statusImagePath!).existsSync();

    final now = DateTime.now();
    final weekSessions = workout.records.where((r) {
      final diff = now.difference(r.date).inDays;
      return diff >= 0 && diff < 7;
    }).length;

    return GestureDetector(
      onTap: () => showStatusEditor(context),
      child: Container(
        height: 206,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: hasImage
              ? null
              : LinearGradient(
                  colors: [
                    Color.lerp(tone.first, spec.card, .28)!,
                    Color.lerp(tone.last, spec.background, .32)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: tone.first.withValues(alpha: .18),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: .14),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.file(
                File(settings.statusImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (hasImage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .42),
                      Colors.black.withValues(alpha: .72),
                    ],
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                if (settings.statusMotion == 2) {
                  return CustomPaint(
                    painter: _StardustPainter(
                      _controller.value,
                      tone.first,
                    ),
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left:
                          -30 + math.sin(_controller.value * math.pi * 2) * 34,
                      top: -46 + math.cos(_controller.value * math.pi * 2) * 18,
                      child: _blob(tone.first.withValues(alpha: .42), 160),
                    ),
                    Positioned(
                      right:
                          -40 + math.cos(_controller.value * math.pi * 2) * 30,
                      bottom:
                          -58 + math.sin(_controller.value * math.pi * 2) * 18,
                      child: _blob(tone.first.withValues(alpha: .30), 190),
                    ),
                    if (settings.statusMotion == 1)
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset(
                            (_controller.value * 2 - 1) * 280,
                            0,
                          ),
                          child: Container(
                            width: 90,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: .11),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tone.first.withValues(alpha: .4),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Text(
                          settings.statusEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  settings.nickname,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    settings.trainingGoal,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '今日状态 · ${_timeAgo(now)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .62),
                                fontSize: 10.5,
                                letterSpacing: .5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    child: Text(
                      settings.statusText,
                      key: ValueKey(settings.statusText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 14,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .1),
                      ),
                    ),
                    child: Row(
                      children: [
                        _miniStat(
                          '${widget.streakDays}',
                          '天坚持',
                        ),
                        _divider(),
                        _miniStat(
                          '$weekSessions/${settings.weeklyGoal}',
                          '本周训练',
                        ),
                        _divider(),
                        _miniStat(
                          '${workout.totalSessions}',
                          '累计次数',
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .56),
              fontSize: 9.5,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: .12),
    );
  }

  String _timeAgo(DateTime now) {
    final h = now.hour;
    if (h < 6) return '凌晨';
    if (h < 11) return '早晨';
    if (h < 14) return '中午';
    if (h < 18) return '下午';
    return '夜晚';
  }
}

class _StardustPainter extends CustomPainter {
  final double progress;
  final Color color;

  _StardustPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 26; i++) {
      final seed = i * 37.0;
      final x =
          (seed * 13 % size.width) + math.sin(progress * math.pi * 2 + i) * 12;
      final baseY = seed * 7 % size.height;
      final y = (baseY - progress * 40) % size.height;
      final radius = 1.0 + (i % 3) * .7;
      paint.color = color.withValues(alpha: .18 + (i % 4) * .06);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StardustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

Future<void> showStatusEditor(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final textController = TextEditingController(text: settings.statusText);
  var emoji = settings.statusEmoji;
  var tone = settings.statusTone;
  var motion = settings.statusMotion;
  String? imagePath = settings.statusImagePath;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final spec = context.watch<ThemeProvider>().currentSpec;
          final palette = statusTones[tone % statusTones.length];
          final hasImage = imagePath != null && File(imagePath!).existsSync();

          Future<void> pickImage() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
                source: ImageSource.gallery, imageQuality: 88);
            if (picked == null) return;
            final dir = await getApplicationDocumentsDirectory();
            final target =
                '${dir.path}/status_${DateTime.now().millisecondsSinceEpoch}.jpg';
            await File(picked.path).copy(target);
            setSheetState(() => imagePath = target);
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .92,
            ),
            decoration: BoxDecoration(
              color: spec.background.withValues(alpha: .98),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(
                color: spec.textPrimary.withValues(alpha: .08),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: spec.textSecondary.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        GradientIconBadge(
                          icon: Icons.bolt_rounded,
                          colors: palette,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '编辑今日状态',
                                style: TextStyle(
                                  color: spec.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '像朋友圈状态一样，展示此刻的你',
                                style: TextStyle(
                                  color: spec.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _StatusPreview(
                      text: textController.text,
                      emoji: emoji,
                      tone: tone,
                      motion: motion,
                      imagePath: imagePath,
                      nickname: settings.nickname,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '状态文案',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      maxLength: 42,
                      maxLines: 2,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: '写下今天想对自己说的话…',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '选择图标',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SettingsProvider.statusEmojis.map((item) {
                        final selected = item == emoji;
                        return GestureDetector(
                          onTap: () => setSheetState(() => emoji = item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? palette.first.withValues(alpha: .2)
                                  : spec.textPrimary.withValues(alpha: .05),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: selected
                                    ? palette.first
                                    : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                            child: Text(item,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '配色氛围',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(statusTones.length, (index) {
                        final selected = tone == index;
                        return GestureDetector(
                          onTap: () => setSheetState(() => tone = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 54,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: statusTones[index],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: statusTones[index]
                                            .first
                                            .withValues(alpha: .45),
                                        blurRadius: 14,
                                      )
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '动效',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          List.generate(statusMotionNames.length, (index) {
                        return ChoiceChip(
                          label: Text(statusMotionNames[index]),
                          selected: motion == index,
                          onSelected: (_) =>
                              setSheetState(() => motion = index),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '背景图片',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickImage,
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: Text(hasImage ? '更换图片' : '从相册选择'),
                          ),
                        ),
                        if (hasImage) ...[
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: () =>
                                setSheetState(() => imagePath = null),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            tooltip: '移除图片',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await settings.setStatus(
                            emoji: emoji,
                            text: textController.text,
                            tone: tone,
                            motion: motion,
                            imagePath: imagePath,
                            clearImage: imagePath == null,
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('保存状态'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  textController.dispose();
}

class _StatusPreview extends StatelessWidget {
  final String text;
  final String emoji;
  final int tone;
  final int motion;
  final String? imagePath;
  final String nickname;

  const _StatusPreview({
    required this.text,
    required this.emoji,
    required this.tone,
    required this.motion,
    required this.imagePath,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final palette = statusTones[tone % statusTones.length];
    final hasImage = imagePath != null && File(imagePath!).existsSync();

    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: hasImage
            ? null
            : LinearGradient(
                colors: [
                  Color.lerp(palette.first, spec.card, .28)!,
                  Color.lerp(palette.last, spec.background, .32)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
        image: hasImage
            ? DecorationImage(
                image: FileImage(File(imagePath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: hasImage
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: .35),
                    Colors.black.withValues(alpha: .7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Pill(
                  label: statusMotionNames[motion.clamp(0, 2)],
                  icon: Icons.auto_awesome,
                  color: Colors.white,
                ),
              ],
            ),
            const Spacer(),
            Text(
              text.trim().isEmpty ? '写点什么吧…' : text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
