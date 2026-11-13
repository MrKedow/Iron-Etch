import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFontOption {
  final String id;
  final String label;
  final String? googleFamily;

  const AppFontOption(this.id, this.label, this.googleFamily);

  bool get isSystem => id == 'system';
  bool get isCustom => id == 'custom';
}

const List<AppFontOption> appFontOptions = [
  AppFontOption('system', '系统默认', null),
  AppFontOption('noto-sans-sc', '思源黑体', 'Noto Sans SC'),
  AppFontOption('noto-serif-sc', '思源宋体', 'Noto Serif SC'),
  AppFontOption('ma-shan-zheng', '马善政毛笔', 'Ma Shan Zheng'),
  AppFontOption('zcool-xiaowei', '站酷小薇', 'ZCOOL XiaoWei'),
  AppFontOption('zcool-qingke', '站酷庆科黄油', 'ZCOOL QingKe HuangYou'),
  AppFontOption('long-cang', '龙藏手写', 'Long Cang'),
  AppFontOption('zhi-mang-xing', '志莽行书', 'Zhi Mang Xing'),
  AppFontOption('liu-jian-mao-cao', '刘建毛草', 'Liu Jian Mao Cao'),
  AppFontOption('noto-sans-jp', 'Noto Sans JP', 'Noto Sans JP'),
  AppFontOption('noto-serif-jp', 'Noto Serif JP', 'Noto Serif JP'),
  AppFontOption('mplus-rounded', 'M PLUS Rounded', 'M PLUS Rounded 1c'),
  AppFontOption('noto-sans-kr', 'Noto Sans KR', 'Noto Sans KR'),
  AppFontOption('nanum-gothic', 'Nanum Gothic', 'Nanum Gothic'),
  AppFontOption('black-han-sans', 'Black Han Sans', 'Black Han Sans'),
  AppFontOption('roboto', 'Roboto', 'Roboto'),
  AppFontOption('montserrat', 'Montserrat', 'Montserrat'),
  AppFontOption('oswald', 'Oswald', 'Oswald'),
  AppFontOption('playfair', 'Playfair Display', 'Playfair Display'),
  AppFontOption('jetbrains-mono', 'JetBrains Mono', 'JetBrains Mono'),
  AppFontOption('bebas-neue', 'Bebas Neue', 'Bebas Neue'),
  AppFontOption('custom', '自定义字体', null),
];

AppFontOption appFontById(String? id) {
  return appFontOptions.firstWhere(
    (item) => item.id == (id ?? 'system'),
    orElse: () => appFontOptions.first,
  );
}

class AppFonts {
  static final Set<String> _loadedCustomFamilies = {};

  static ThemeData apply(
    ThemeData base, {
    required String fontId,
    String? customFamily,
  }) {
    final option = appFontById(fontId);
    String? family;
    if (option.isSystem) return base;
    if (option.isCustom) {
      family = customFamily;
      if (family == null || !_loadedCustomFamilies.contains(family)) {
        return base;
      }
    } else {
      family = option.googleFamily;
      if (family == null) return base;
      try {
        family = GoogleFonts.getFont(family).fontFamily ?? family;
      } catch (_) {
        return base;
      }
    }
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: family),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    );
  }

  static Future<String?> loadCustomFont({
    required String family,
    required String path,
  }) async {
    if (family.isEmpty || path.isEmpty) return null;
    if (_loadedCustomFamilies.contains(family)) return family;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      final loader = FontLoader(family)
        ..addFont(
          Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
        );
      await loader.load();
      _loadedCustomFamilies.add(family);
      return family;
    } catch (_) {
      return null;
    }
  }
}
