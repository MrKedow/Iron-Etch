import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../l10n/localized_material.dart';
import '../providers/app_providers.dart';

/// 应用内相册：完整授权时显示全部图片，Android 14 受限授权时只显示
/// 用户选中的图片，并提供“管理已选照片”重新打开系统选择器。
class PhotoPickerPage extends StatefulWidget {
  const PhotoPickerPage({super.key});

  @override
  State<PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends State<PhotoPickerPage> {
  static const int _pageSize = 80;

  final ScrollController _scroll = ScrollController();
  final List<AssetEntity> _assets = [];
  AssetPathEntity? _path;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _picking = false;
  PermissionState _permission = PermissionState.notDetermined;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _initialize();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _initialize() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (!mounted) return;
    setState(() {
      _permission = state;
      _path = paths.isEmpty ? null : paths.first;
      _assets.clear();
      _total = 0;
      _loading = true;
    });
    if (_path == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _total = await _path!.assetCountAsync;
    await _loadMore(initial: true);
  }

  Future<void> _loadMore({bool initial = false}) async {
    if (_loadingMore) return;
    final path = _path;
    if (path == null) return;
    if (!initial && _assets.length >= _total) return;
    setState(() {
      _loadingMore = true;
      if (initial) _loading = true;
    });
    final end = math.min(_total, _assets.length + _pageSize);
    final list = await path.getAssetListRange(
      start: _assets.length,
      end: end,
    );
    if (!mounted) return;
    setState(() {
      _assets.addAll(list);
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _manageSelection() async {
    await PhotoManager.presentLimited(type: RequestType.image);
    if (!mounted) return;
    await _initialize();
  }

  Future<void> _pick(AssetEntity asset) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await asset.file;
      if (file != null) {
        if (mounted) Navigator.pop(context, file.path);
        return;
      }
      final bytes = await asset.originBytes;
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final target = File('${dir.path}/picked_${asset.id}.jpg');
      await target.writeAsBytes(bytes, flush: true);
      if (mounted) Navigator.pop(context, target.path);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final limited = _permission == PermissionState.limited;
    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        title: Text(context.tr('选择照片')),
        actions: [
          if (limited)
            TextButton(
              onPressed: _manageSelection,
              child: Text(context.tr('管理已选照片')),
            ),
        ],
      ),
      body: Column(
        children: [
          if (limited)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: spec.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 15, color: spec.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      context.tr('当前仅可访问你选中的照片'),
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _manageSelection,
                    child: Text(context.tr('选择更多')),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: spec.primary),
                  )
                : _assets.isEmpty
                    ? Center(
                        child: Text(
                          context.tr('没有可用的照片'),
                          style: TextStyle(color: spec.textSecondary),
                        ),
                      )
                    : GridView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(6),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: _assets.length,
                        itemBuilder: (context, index) => _tile(_assets[index]),
                      ),
          ),
          if (_picking)
            LinearProgressIndicator(
              color: spec.primary,
              backgroundColor: spec.primary.withValues(alpha: .12),
            ),
        ],
      ),
    );
  }

  Widget _tile(AssetEntity asset) {
    return GestureDetector(
      onTap: () => _pick(asset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(
            const ThumbnailSize(300, 300),
            quality: 85,
          ),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) {
              return const ColoredBox(color: Color(0x11000000));
            }
            return Image.memory(
              data,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}
