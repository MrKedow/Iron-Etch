import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppFontOption {
  final String id;
  final String label;

  /// Path inside the google/fonts repository, e.g. `ofl/notosanssc/...ttf`.
  final String? repoPath;

  const AppFontOption(this.id, this.label, this.repoPath);

  bool get isSystem => id == 'system';
  bool get isCustom => id == 'custom';
  bool get isDownloadable => repoPath != null;
}

const List<String> _githubProxyPrefixes = [
  'https://gh.monlor.com/',
  'https://gh.acmsz.top/',
  'https://gh-proxy.org/',
  'https://gh-proxy.com/',
  'https://ghproxy.imciel.com/',
  'https://ghproxy.net/',
  'https://ghfast.top/',
  'https://gh.llkk.cc/',
  'https://mirror.ghproxy.com/',
  'https://ghmirror.com/',
  'https://ghproxy.link/',
  'https://ghproxy.cn/',
  'https://hub.gitmirror.com/',
  'https://gh.ddlc.top/',
  'https://gh-proxy.net/',
  'https://gh.6yit.com/',
  'https://gh.xxooo.cf/',
  'https://ghproxy.cfd/',
  'https://gh.api.99988866.xyz/',
  'https://gh-proxy.ygxz.in/',
];

const List<AppFontOption> appFontOptions = [
  AppFontOption('system', '系统默认', null),
  AppFontOption(
      'noto-sans-sc', '思源黑体', 'ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf'),
  AppFontOption(
      'noto-serif-sc', '思源宋体', 'ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf'),
  AppFontOption(
      'ma-shan-zheng', '马善政毛笔', 'ofl/mashanzheng/MaShanZheng-Regular.ttf'),
  AppFontOption(
      'zcool-xiaowei', '站酷小薇', 'ofl/zcoolxiaowei/ZCOOLXiaoWei-Regular.ttf'),
  AppFontOption('zcool-qingke', '站酷庆科黄油',
      'ofl/zcoolqingkehuangyou/ZCOOLQingKeHuangYou-Regular.ttf'),
  AppFontOption('long-cang', '龙藏手写', 'ofl/longcang/LongCang-Regular.ttf'),
  AppFontOption(
      'zhi-mang-xing', '志莽行书', 'ofl/zhimangxing/ZhiMangXing-Regular.ttf'),
  AppFontOption('liu-jian-mao-cao', '刘建毛草',
      'ofl/liujianmaocao/LiuJianMaoCao-Regular.ttf'),
  AppFontOption('noto-sans-jp', 'Noto Sans JP',
      'ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf'),
  AppFontOption('noto-serif-jp', 'Noto Serif JP',
      'ofl/notoserifjp/NotoSerifJP%5Bwght%5D.ttf'),
  AppFontOption('mplus-rounded', 'M PLUS Rounded',
      'ofl/mplusrounded1c/MPLUSRounded1c-Regular.ttf'),
  AppFontOption('noto-sans-kr', 'Noto Sans KR',
      'ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf'),
  AppFontOption('nanum-gothic', 'Nanum Gothic',
      'ofl/nanumgothic/NanumGothic-Regular.ttf'),
  AppFontOption('black-han-sans', 'Black Han Sans',
      'ofl/blackhansans/BlackHanSans-Regular.ttf'),
  AppFontOption('roboto', 'Roboto', 'ofl/roboto/Roboto%5Bwdth%2Cwght%5D.ttf'),
  AppFontOption(
      'montserrat', 'Montserrat', 'ofl/montserrat/Montserrat%5Bwght%5D.ttf'),
  AppFontOption('oswald', 'Oswald', 'ofl/oswald/Oswald%5Bwght%5D.ttf'),
  AppFontOption('playfair', 'Playfair Display',
      'ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf'),
  AppFontOption('jetbrains-mono', 'JetBrains Mono',
      'ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf'),
  AppFontOption(
      'bebas-neue', 'Bebas Neue', 'ofl/bebasneue/BebasNeue-Regular.ttf'),
  AppFontOption('custom', '自定义字体', null),
];

AppFontOption appFontById(String? id) {
  return appFontOptions.firstWhere(
    (item) => item.id == (id ?? 'system'),
    orElse: () => appFontOptions.first,
  );
}

class FontDownloadStatus {
  final bool downloading;
  final double progress;
  final double speedBytesPerSecond;
  final String? error;

  const FontDownloadStatus({
    this.downloading = false,
    this.progress = 0,
    this.speedBytesPerSecond = 0,
    this.error,
  });
}

class _FontNotifier extends ChangeNotifier {
  void emit() => notifyListeners();
}

class AppFonts {
  static final _FontNotifier _notifier = _FontNotifier();

  static ChangeNotifier get notifier => _notifier;

  static const MethodChannel _channel =
      MethodChannel('com.mrkedow.ironetch/epub');
  static const String _rawBase =
      'https://raw.githubusercontent.com/google/fonts/main/';

  static final Map<String, String> _loadedFamilies = {};
  static final Set<String> _loadedCustomFamilies = {};
  static final Map<String, FontDownloadStatus> _statuses = {};
  static final Map<String, Future<String?>> _inflight = {};
  static final Map<String, List<String>> _candidateCache = {};
  static final Set<String> _knownDownloaded = {};
  static bool _nativeUnavailable = false;

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

  static FontDownloadStatus statusFor(String id) =>
      _statuses[id] ?? const FontDownloadStatus();

  static bool isKnownDownloaded(String id) => _knownDownloaded.contains(id);

  static Future<bool> isDownloaded(AppFontOption option) async {
    if (!option.isDownloadable) return false;
    try {
      final file = await _fontFile(option);
      final ok = await file.exists() && await file.length() > 1024;
      if (ok) {
        _knownDownloaded.add(option.id);
      } else {
        _knownDownloaded.remove(option.id);
      }
      return ok;
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
    // Load a previously downloaded file without starting a network request.
    // Use the direct runner so it never blocks a user-initiated download.
    await _runDownload(option, allowNetwork: false);
  }

  static Future<String?> downloadAndLoad(
    AppFontOption option, {
    bool allowNetwork = true,
  }) {
    if (!option.isDownloadable) return Future.value(null);
    final loaded = _loadedFamilies[option.id];
    if (loaded != null) return Future.value(loaded);
    final existing = _inflight[option.id];
    if (existing != null) return existing;
    final future = _runDownload(option, allowNetwork: allowNetwork);
    _inflight[option.id] = future;
    future.whenComplete(() => _inflight.remove(option.id));
    return future;
  }

  static void _updateStatus(String id, FontDownloadStatus status) {
    _statuses[id] = status;
    _notifier.emit();
  }

  static Future<String?> _runDownload(
    AppFontOption option, {
    required bool allowNetwork,
  }) async {
    final file = await _fontFile(option);
    try {
      var exists = await file.exists() && await file.length() > 1024;
      if (!exists) {
        if (!allowNetwork) return null;
        final ok = await _downloadToFile(option, file);
        if (!ok) {
          _updateStatus(
            option.id,
            const FontDownloadStatus(error: 'download_failed'),
          );
          return null;
        }
        exists = await file.exists() && await file.length() > 1024;
        if (!exists) return null;
      }
      final bytes = await file.readAsBytes();
      if (!_looksLikeFont(bytes)) {
        await file.delete();
        _knownDownloaded.remove(option.id);
        _updateStatus(
          option.id,
          const FontDownloadStatus(error: 'invalid_font'),
        );
        return null;
      }
      final family =
          'AppFont_${option.id}_${DateTime.now().microsecondsSinceEpoch}';
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFamilies[option.id] = family;
      _knownDownloaded.add(option.id);
      _updateStatus(option.id, const FontDownloadStatus());
      return family;
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _knownDownloaded.remove(option.id);
      _updateStatus(
        option.id,
        const FontDownloadStatus(error: 'download_failed'),
      );
      return null;
    }
  }

  static bool _looksLikeFont(List<int> bytes) {
    if (bytes.length < 4) return false;
    final tag = String.fromCharCodes(bytes.sublist(0, 4));
    if (tag == 'OTTO' || tag == 'true' || tag == 'typ1' || tag == 'ttcf') {
      return true;
    }
    return bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0;
  }

  static List<String> _candidateUrls(AppFontOption option) {
    final path = option.repoPath!;
    final raw = '$_rawBase$path';
    return [
      raw,
      'https://fastly.jsdelivr.net/gh/google/fonts@main/$path',
      'https://gcore.jsdelivr.net/gh/google/fonts@main/$path',
      'https://cdn.jsdelivr.net/gh/google/fonts@main/$path',
      for (final prefix in _githubProxyPrefixes) '$prefix$raw',
    ];
  }

  static Future<List<String>> _rankedCandidates(AppFontOption option) async {
    final cached = _candidateCache[option.id];
    if (cached != null) return cached;
    final urls = _candidateUrls(option);
    final results = await Future.wait(urls.map(_probeUrl));
    final ranked = <MapEntry<String, double>>[];
    for (var i = 0; i < urls.length; i++) {
      final throughput = results[i];
      if (throughput != null) ranked.add(MapEntry(urls[i], throughput));
    }
    ranked.sort((a, b) => b.value.compareTo(a.value));
    final order = ranked.map((entry) => entry.key).toList();
    if (order.isNotEmpty) _candidateCache[option.id] = order;
    return order.isEmpty ? urls : order;
  }

  /// 返回实测吞吐量（字节/毫秒）；失败或内容不是字体时返回 null。
  static Future<double?> _probeUrl(String url) async {
    final client = http.Client();
    try {
      final sw = Stopwatch()..start();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=0-131071';
      final response =
          await client.send(request).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200 && response.statusCode != 206) return null;
      final bytes = <int>[];
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 4),
        )) {
          bytes.addAll(chunk);
          if (bytes.length >= 98304) break;
        }
      } catch (_) {
        // Partial probes are still useful for ranking throughput.
      }
      if (bytes.length < 4096) return null;
      if (!_looksLikeFont(bytes)) return null;
      final elapsed = math.max(1, sw.elapsedMilliseconds);
      return bytes.length / elapsed;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<bool> _downloadToFile(
    AppFontOption option,
    File file,
  ) async {
    final candidates = await _rankedCandidates(option);
    for (final url in candidates) {
      _updateStatus(
        option.id,
        const FontDownloadStatus(downloading: true),
      );
      try {
        if (Platform.isAndroid &&
            !_nativeUnavailable &&
            await _nativeDownload(option, url, file)) {
          return true;
        }
        if (await _streamDownload(option, url, file)) return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<bool> _nativeDownload(
    AppFontOption option,
    String url,
    File file,
  ) async {
    try {
      final start = await _channel.invokeMapMethod<String, dynamic>(
        'enqueueDownload',
        {
          'url': url,
          'fileName': 'font_${option.id}.ttf',
          'title': '下载字体：${option.label}',
          'description': '正在下载内置字体，可切到后台继续',
        },
      );
      if (start == null || start['id'] == null) {
        _nativeUnavailable = true;
        return false;
      }
      final id = (start['id'] as num).toInt();
      final path = start['path'] as String;
      var lastBytes = 0;
      var lastProgress = 0.0;
      var lastDownloaded = -1;
      var lastGrowth = DateTime.now();
      final speedWatch = Stopwatch()..start();
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final status = await _channel.invokeMapMethod<String, dynamic>(
          'downloadStatus',
          {'downloadId': id},
        );
        if (status == null) return false;
        final code = (status['status'] as num).toInt();
        final downloaded = (status['downloaded'] as num).toInt();
        final total = (status['total'] as num).toInt();
        if (downloaded > lastDownloaded) {
          lastDownloaded = downloaded;
          lastGrowth = DateTime.now();
        } else if (DateTime.now().difference(lastGrowth) >
            const Duration(seconds: 15)) {
          return false;
        }
        var speed = 0.0;
        if (speedWatch.elapsedMilliseconds >= 500) {
          final delta = downloaded - lastBytes;
          if (delta > 0) {
            speed = delta / speedWatch.elapsedMilliseconds * 1000.0;
          }
          lastBytes = downloaded;
          speedWatch.reset();
        }
        if (total > 0) {
          lastProgress = (downloaded / total).clamp(0.0, 1.0);
        }
        _updateStatus(
          option.id,
          FontDownloadStatus(
            downloading: true,
            progress: lastProgress,
            speedBytesPerSecond: speed,
          ),
        );
        if (code == 8) {
          final downloadedFile = File(path);
          final valid = await _validateFile(downloadedFile);
          if (!valid) {
            try {
              await downloadedFile.delete();
            } catch (_) {}
            return false;
          }
          if (await file.exists()) await file.delete();
          await downloadedFile.copy(file.path);
          try {
            await downloadedFile.delete();
          } catch (_) {}
          return true;
        }
        if (code == 16 || code == -1) return false;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _validateFile(File file) async {
    try {
      if (!await file.exists() || await file.length() < 1024) return false;
      final head = await file.openRead(0, 4).first;
      return _looksLikeFont(head);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _streamDownload(
    AppFontOption option,
    String url,
    File file,
  ) async {
    final part = File('${file.path}.part');
    final client = http.Client();
    try {
      var existing = 0;
      if (await part.exists()) {
        existing = await part.length();
        if (existing > 0 && !await _validateFile(part)) {
          try {
            await part.delete();
          } catch (_) {}
          existing = 0;
        }
      }
      final request = http.Request('GET', Uri.parse(url));
      if (existing > 0) {
        request.headers['Range'] = 'bytes=$existing-';
      }
      final response =
          await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 206) {
        return false;
      }
      final resuming = response.statusCode == 206 && existing > 0;
      if (!resuming) existing = 0;
      final total = resuming
          ? existing + (response.contentLength ?? 0)
          : (response.contentLength ?? 0);
      var received = existing;
      var lastReport = 0;
      final sink = part.openWrite(
        mode: resuming ? FileMode.append : FileMode.write,
      );
      final sw = Stopwatch()..start();
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 15),
        )) {
          sink.add(chunk);
          received += chunk.length;
          if (sw.elapsedMilliseconds - lastReport > 400) {
            lastReport = sw.elapsedMilliseconds;
            _updateStatus(
              option.id,
              FontDownloadStatus(
                downloading: true,
                progress: total > 0 ? (received / total).clamp(0.0, 1.0) : 0,
                speedBytesPerSecond:
                    received / math.max(1, sw.elapsedMilliseconds) * 1000.0,
              ),
            );
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (received < 1024) return false;
      if (!await _validateFile(part)) {
        try {
          await part.delete();
        } catch (_) {}
        return false;
      }
      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      return true;
    } catch (_) {
      // Keep a valid partial file so the next source can resume from it.
      return false;
    } finally {
      client.close();
    }
  }

  static Future<void> delete(AppFontOption option) async {
    if (!option.isDownloadable) return;
    _loadedFamilies.remove(option.id);
    _knownDownloaded.remove(option.id);
    _candidateCache.remove(option.id);
    _statuses.remove(option.id);
    _notifier.emit();
    try {
      final file = await _fontFile(option);
      if (await file.exists()) await file.delete();
      final part = File('${file.path}.part');
      if (await part.exists()) await part.delete();
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
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedCustomFamilies.add(family);
      return family;
    } catch (_) {
      return null;
    }
  }
}
