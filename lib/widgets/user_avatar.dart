import 'dart:io';

import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.path,
    required this.size,
    required this.fallback,
    this.circle = true,
    this.borderRadius,
  });

  final String? path;
  final double size;
  final Widget fallback;
  final bool circle;
  final BorderRadius? borderRadius;

  File? _resolveFile() {
    try {
      final value = path?.trim();
      if (value == null || value.isEmpty) return null;
      final file = File(value);
      if (!file.existsSync()) return null;
      return file;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _resolveFile();
    final child = file == null
        ? SizedBox(width: size, height: size, child: Center(child: fallback))
        : Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).round(),
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => SizedBox(
                width: size, height: size, child: Center(child: fallback)),
          );
    if (circle) {
      return ClipOval(child: child);
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: child,
    );
  }
}
