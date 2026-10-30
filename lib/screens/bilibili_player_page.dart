import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';

import '../providers/app_providers.dart';

class BilibiliPlayerPage extends StatefulWidget {
  final String name;
  final String bvid;

  const BilibiliPlayerPage({
    super.key,
    required this.name,
    required this.bvid,
  });

  @override
  State<BilibiliPlayerPage> createState() => _BilibiliPlayerPageState();
}

class _BilibiliPlayerPageState extends State<BilibiliPlayerPage> {
  final WebviewController _web = WebviewController();
  late final Future<void> _initFuture;
  StreamSubscription<LoadingState>? _loadingSub;
  StreamSubscription<WebErrorStatus>? _errorSub;
  bool _loading = true;
  String? _error;

  String get _playerUrl =>
      'https://player.bilibili.com/player.html?bvid=${widget.bvid}'
      '&page=1&high_quality=1&danmaku=0&autoplay=1';

  @override
  void initState() {
    super.initState();
    _initFuture = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _web.initialize();
    _loadingSub = _web.loadingState.listen((state) {
      if (!mounted) return;
      if (state == LoadingState.loading) {
        setState(() {
          _loading = true;
          _error = null;
        });
      } else if (state == LoadingState.navigationCompleted) {
        setState(() => _loading = false);
        unawaited(_web.executeScript(_injectedScript));
      }
    });
    _errorSub = _web.onLoadError.listen((_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'B 站页面加载失败，请检查网络后重试。';
      });
    });
    await _web.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    );
    await _web.loadUrl(_playerUrl);
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _web.loadUrl(_playerUrl);
  }

  void _handleBack() {
    if (mounted) Navigator.of(context).pop();
  }

  static const String _injectedScript = '''
(function() {
  if (window.__ftBiliInjected) return;
  window.__ftBiliInjected = true;
  var style = document.createElement('style');
  style.innerHTML = '.open-app-img,.open-app-btn,.launch-app-btn,.fixed-open-app{display:none!important;}';
  if (document.head) document.head.appendChild(style);
  document.addEventListener('click', function(e) {
    var a = e.target && e.target.closest ? e.target.closest('a') : null;
    if (!a) return;
    if (a.target === '_blank') a.target = '_self';
    if (a.href && a.href.indexOf('bilibili://') === 0) e.preventDefault();
  }, true);
})();
''';

  @override
  void dispose() {
    _loadingSub?.cancel();
    _errorSub?.cancel();
    _web.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: spec.background,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'B 站 · 应用内播放',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'WebView2 初始化失败：${snapshot.error}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }
            return Stack(
              children: [
                Positioned.fill(child: Webview(_web)),
                if (_loading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: spec.primary,
                    ),
                  ),
                if (_error != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: spec.background,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.smart_display_outlined,
                                size: 38,
                                color: spec.textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: spec.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _reload,
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('重试'),
                              ),
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
      ),
    );
  }
}
