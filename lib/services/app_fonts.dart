import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppFontOption {
  final String id;
  final String label;
  final String? url;

  const AppFontOption(this.id, this.label, this.url);

  bool get isSystem => id == 'system';
  bool get isCustom => id == 'custom';
  bool get isDownloadable => url != null;
}

const String _fontCdn = 'https://fastly.jsdelivr.net/gh/google/fonts@main';

const List<AppFontOption> appFontOptions = [
  AppFontOption('system', '系统默认', null),
  AppFontOption('noto-sans-sc', '思源黑体',
      '$_fontCdn/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf'),
  AppFontOption('noto-serif-sc', '思源宋体',
      '$_fontCdn/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf'),
  AppFontOption('ma-shan-zheng', '马善政毛笔',
      '$_fontCdn/ofl/mashanzheng/MaShanZheng-Regular.ttf'),
  AppFontOption('zcool-xiaowei', '站酷小薇',
      '$_fontCdn/ofl/zcoolxiaowei/ZCOOLXiaoWei-Regular.ttf'),
  AppFontOption('zcool-qingke', '站酷庆科黄油',
      '$_fontCdn/ofl/zcoolqingkehuangyou/ZCOOLQingKeHuangYou-Regular.ttf'),
  AppFontOption(
      'long-cang', '龙藏手写', '$_fontCdn/ofl/longcang/LongCang-Regular.ttf'),
  AppFontOption('zhi-mang-xing', '志莽行书',
      '$_fontCdn/ofl/zhimangxing/ZhiMangXing-Regular.ttf'),
  AppFontOption('liu-jian-mao-cao', '刘建毛草',
      '$_fontCdn/ofl/liujianmaocao/LiuJianMaoCao-Regular.ttf'),
  AppFontOption('noto-sans-jp', 'Noto Sans JP',
      '$_fontCdn/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf'),
  AppFontOption('noto-serif-jp', 'Noto Serif JP',
      '$_fontCdn/ofl/notoserifjp/NotoSerifJP%5Bwght%5D.ttf'),
  AppFontOption('mplus-rounded', 'M PLUS Rounded',
      '$_fontCdn/ofl/mplusrounded1c/MPLUSRounded1c-Regular.ttf'),
  AppFontOption('noto-sans-kr', 'Noto Sans KR',
      '$_fontCdn/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf'),
  AppFontOption('nanum-gothic', 'Nanum Gothic',
      '$_fontCdn/ofl/nanumgothic/NanumGothic-Regular.ttf'),
  AppFontOption('black-han-sans', 'Black Han Sans',
      '$_fontCdn/ofl/blackhansans/BlackHanSans-Regular.ttf'),
  AppFontOption(
      'roboto', 'Roboto', '$_fontCdn/ofl/roboto/Roboto%5Bwdth%2Cwght%5D.ttf'),
  AppFontOption('montserrat', 'Montserrat',
      '$_fontCdn/ofl/montserrat/Montserrat%5Bwght%5D.ttf'),
  AppFontOption(
      'oswald', 'Oswald', '$_fontCdn/ofl/oswald/Oswald%5Bwght%5D.ttf'),
  AppFontOption('playfair', 'Playfair Display',
      '$_fontCdn/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf'),
  AppFontOption('jetbrains-mono', 'JetBrains Mono',
      '$_fontCdn/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf'),
  AppFontOption('bebas-neue', 'Bebas Neue',
      '$_fontCdn/ofl/bebasneue/BebasNeue-Regular.ttf'),
  AppFontOption('custom', '自定义字体', null),
];

AppFontOption appFontById(String? id) {
  return appFontOptions.firstWhere(
    (item) => item.id == (id ?? 'system'),
    orElse: () => appFontOptions.first,
  );
}

class AppFonts {
  static final Map<String, String> _loadedFamilies = {};
  static final Set<String> _loadedCustomFamilies = {};

  static Future<Directory> _fontDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}fonts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _fontFile(AppFontOption option) async {
    final dir = await _fontDirectory();
    return File('${dir.path}${Platform.pathSeparator}${option.id}.ttf');
  }

  static Future<bool> isDownloaded(AppFontOption option) async {
    if (!option.isDownloadable) return false;
    try {
      final file = await _fontFile(option);
      return await file.exists() && await file.length() > 1024;
    } catch (_) {
      return false;
    }
  }

  static bool isLoaded(String fontId) => _loadedFamilies.containsKey(fontId);

  static ThemeData apply(
    ThemeData base, {
    required String fontId,
    String? customFamily,
  }) {
    final option = appFontById(fontId);
    if (option.isSystem) return base;
    if (option.isCustom) {
      final family = customFamily;
      if (family == null || !_loadedCustomFamilies.contains(family)) {
        return base;
      }
      return _applyFamily(
        base,
        textTheme: base.textTheme.apply(fontFamily: family),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
      );
    }
    final family = _loadedFamilies[option.id];
    if (family == null) return base;
    return _applyFamily(
      base,
      textTheme: base.textTheme.apply(fontFamily: family),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    );
  }

  static ThemeData _applyFamily(
    ThemeData base, {
    required TextTheme textTheme,
    required TextTheme primaryTextTheme,
  }) {
    final themed = base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
    );

    TextStyle? fit(TextStyle? style) {
      if (style == null) return null;
      final source = _styleForWeight(textTheme, style.fontWeight);
      final family = source.fontFamily;
      if (family == null) return style;
      return style.copyWith(
        fontFamily: family,
        fontFamilyFallback: source.fontFamilyFallback,
      );
    }

    ButtonStyle fitButton(ButtonStyle? style) {
      if (style == null) return const ButtonStyle();
      final property = style.textStyle;
      if (property == null) return style;
      return style.copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => fit(property.resolve(states)),
        ),
      );
    }

    return themed.copyWith(
      appBarTheme: themed.appBarTheme.copyWith(
        titleTextStyle: fit(themed.appBarTheme.titleTextStyle),
      ),
      dialogTheme: themed.dialogTheme.copyWith(
        titleTextStyle: fit(themed.dialogTheme.titleTextStyle),
        contentTextStyle: fit(themed.dialogTheme.contentTextStyle),
      ),
      inputDecorationTheme: themed.inputDecorationTheme.copyWith(
        labelStyle: fit(themed.inputDecorationTheme.labelStyle),
        hintStyle: fit(themed.inputDecorationTheme.hintStyle),
        suffixStyle: fit(themed.inputDecorationTheme.suffixStyle),
      ),
      chipTheme: themed.chipTheme.copyWith(
        labelStyle: fit(themed.chipTheme.labelStyle),
      ),
      snackBarTheme: themed.snackBarTheme.copyWith(
        contentTextStyle: fit(themed.snackBarTheme.contentTextStyle),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: fitButton(themed.elevatedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: fitButton(themed.textButtonTheme.style),
      ),
    );
  }

  static TextStyle _styleForWeight(TextTheme theme, FontWeight? weight) {
    final value = weight?.value ?? 400;
    final candidates = value >= 700
        ? [theme.titleLarge, theme.bodyLarge, theme.bodyMedium]
        : value >= 500
            ? [theme.titleMedium, theme.bodyMedium, theme.bodyLarge]
            : [theme.bodyMedium, theme.bodyLarge, theme.labelMedium];
    for (final style in candidates) {
      if (style?.fontFamily != null) return style!;
    }
    return const TextStyle();
  }

  static Future<void> preload(String fontId, {String? customFamily}) async {
    final option = appFontById(fontId);
    if (option.isSystem) return;
    if (option.isCustom) {
      final family = customFamily;
      if (family == null || _loadedCustomFamilies.contains(family)) return;
      return;
    }
    if (_loadedFamilies.containsKey(option.id)) return;
    await downloadAndLoad(option, allowNetwork: false);
  }

  static Future<String?> downloadAndLoad(
    AppFontOption option, {
    bool allowNetwork = true,
  }) async {
    if (!option.isDownloadable) return null;
    final loaded = _loadedFamilies[option.id];
    if (loaded != null) return loaded;
    try {
      final file = await _fontFile(option);
      if (!await file.exists() || await file.length() < 1024) {
        if (!allowNetwork || option.url == null) return null;
        final response = await http
            .get(Uri.parse(option.url!))
            .timeout(const Duration(seconds: 90));
        if (response.statusCode != 200 || response.bodyBytes.length < 1024) {
          return null;
        }
        await file.writeAsBytes(response.bodyBytes, flush: true);
      }
      final bytes = await file.readAsBytes();
      if (bytes.length < 1024) {
        await file.delete();
        return null;
      }
      final family =
          'AppFont_${option.id}_${DateTime.now().microsecondsSinceEpoch}';
      final loader = FontLoader(family)
        ..addFont(
            Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
      _loadedFamilies[option.id] = family;
      return family;
    } catch (_) {
      try {
        final file = await _fontFile(option);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      return null;
    }
  }

  static Future<void> delete(AppFontOption option) async {
    if (!option.isDownloadable) return;
    _loadedFamilies.remove(option.id);
    try {
      final file = await _fontFile(option);
      if (await file.exists()) await file.delete();
    } catch (_) {}
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
