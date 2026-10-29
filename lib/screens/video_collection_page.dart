import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'bilibili_player_page.dart';

class VideoCollectionPage extends StatefulWidget {
  const VideoCollectionPage({super.key});

  @override
  State<VideoCollectionPage> createState() => _VideoCollectionPageState();
}

class _VideoCollectionPageState extends State<VideoCollectionPage> {
  static const String _assetPath = 'assets/bili_list.json';

  static const Map<String, String> _displayNames = {
    'chenbolin': '陈柏龄',
    'yangwang': '仰望尾迹云',
    'anna': '安娜 Growingannanas',
    'mizi': 'Mizi（一起健身吧MIZI）',
  };

  static const Map<String, String> _bilibiliMids = {
    'pamela': '604003146',
    'zhouliuye': '62540916',
    'jo': '1462582672',
    'hanxiaosi': '369750017',
    'ouyangchunxiao': '493570956',
    'shugui': '1531707',
    'maoshu': '13716885',
    'anna': '3493094769036225',
    'mizi': '287453675',
    'eleni': '3546961800072012',
    'haorensongsong': '2078781964',
    'kaishengwang': '2100737396',
    'zby': '236094881',
    'chenbolin': '401129886',
    'shuaisoserious': '66391032',
    'yangwang': '1879203169',
    'kongboshi': '356634017',
    'zuojiao': '524909826',
    'yisulin': '2923121',
    'coffee': '304020239',
    'chloeting': '417267978',
    'fanliyuan': '63486758',
    'yerenluosi': '1718577682',
    'baoge': '269380821',
    'yang': '432760219',
  };

  static const Map<String, String> _bilibiliBvids = {
    'pamela': 'BV15Bn469ETB',
    'zhouliuye': 'BV1sA411Q7R3',
    'jo': 'BV1kGxM64Epk',
    'hanxiaosi': 'BV18snq6VEkS',
    'ouyangchunxiao': 'BV1omny66E3C',
    'shugui': 'BV1RU4y1b7t4',
    'maoshu': 'BV1PrxL6DErs',
    'anna': 'BV1LUx368ErY',
    'eleni': 'BV1qrn96iEYg',
    'haorensongsong': 'BV1Hk4y187jF',
    'kaishengwang': 'BV1UFxM6vETD',
    'zby': 'BV1vcnb6oEeE',
    'chenbolin': 'BV18P4y147vJ',
    'shuaisoserious': 'BV1zLnn6LEkj',
    'yangwang': 'BV1iyxE6LEUd',
    'kongboshi': 'BV1dNn96cET5',
    'zuojiao': 'BV1NNXLBSEcf',
    'yisulin': 'BV1V7QLYMESC',
    'coffee': 'BV1F9nE6rEn3',
    'chloeting': 'BV1HT4y1M7tJ',
    'fanliyuan': 'BV1zDxL6kEaK',
    'yerenluosi': 'BV1Uent6LEDR',
    'baoge': 'BV1cW411p7nW',
    'yang': 'BV1PAJv6oEy7',
  };

  List<_VideoCategory> _categories = const [];
  bool _loading = true;
  String? _error;
  String _selected = '全部';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final categories = <_VideoCategory>[];
      for (final rawCategory
          in (data['categories'] as List<dynamic>? ?? const [])) {
        final category = rawCategory as Map<String, dynamic>;
        final items = <_VideoCreator>[];
        for (final rawItem
            in (category['items'] as List<dynamic>? ?? const [])) {
          final item = rawItem as Map<String, dynamic>;
          final id = item['id'] as String;
          final mid = _bilibiliMids[id];
          final bvid = _bilibiliBvids[id];
          if (mid == null || bvid == null) continue;
          items.add(
            _VideoCreator(
              id: id,
              name: _displayNames[id] ?? item['name'] as String,
              tags: (item['tags'] as List<dynamic>? ?? const [])
                  .map((tag) => tag.toString())
                  .toList(),
              audience: item['audience'] as String? ?? '',
              bvid: bvid,
            ),
          );
        }
        categories.add(
          _VideoCategory(
            id: category['id'] as String,
            name: category['name'] as String,
            items: items,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '视频合集加载失败，请稍后重试。';
        _loading = false;
      });
    }
  }

  int get _totalCreators =>
      _categories.fold(0, (sum, category) => sum + category.items.length);

  List<_VideoCategory> get _visibleCategories {
    if (_selected == '全部') return _categories;
    return _categories.where((category) => category.id == _selected).toList();
  }

  void _openCreator(_VideoCreator creator) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BilibiliPlayerPage(
          name: creator.name,
          bvid: creator.bvid,
        ),
      ),
    );
  }

  void _showInfo(AppThemeSpec spec) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: spec.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '关于视频合集',
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '点击卡片会在应用内播放该 UP 主的 B 站视频，视频由 B 站播放器直接播放，不缓存、不代理。',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 12.5,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '仅保留已确认可播放视频的 UP 主，找不到可用视频的已从列表移除。',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 12.5,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('视频合集'),
        actions: [
          IconButton(
            tooltip: '说明',
            onPressed: () => _showInfo(spec),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(spec)
              : _content(spec),
    );
  }

  Widget _errorView(AppThemeSpec spec) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.smart_display_outlined,
                color: spec.textSecondary,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AppThemeSpec spec) {
    final categories = _visibleCategories;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(16),
          gradient: LinearGradient(
            colors: [
              spec.primary.withValues(alpha: .16),
              spec.secondary.withValues(alpha: .06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            children: [
              GradientIconBadge(
                icon: Icons.smart_display_rounded,
                colors: [spec.primary, spec.secondary],
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'B 站跟练入口',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalCreators 位 UP 主 · 应用内播放',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '按训练目标分类，点击卡片在应用内播放 UP 主的 B 站视频。',
          style: TextStyle(
            color: spec.textSecondary,
            fontSize: 11.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(spec, '全部', '全部'),
              for (final category in _categories) ...[
                const SizedBox(width: 8),
                _filterChip(spec, category.id, category.name),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final category in categories) ...[
          SectionHeader(
            title: category.name,
            subtitle: '${category.items.length} 位 UP 主',
            padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
          ),
          for (final creator in category.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _creatorCard(spec, creator),
            ),
        ],
      ],
    );
  }

  Widget _filterChip(AppThemeSpec spec, String id, String label) {
    final selected = _selected == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selected = id),
      selectedColor: spec.primary.withValues(alpha: .16),
      labelStyle: TextStyle(
        color: selected ? spec.primary : spec.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? spec.primary.withValues(alpha: .45)
            : spec.textPrimary.withValues(alpha: .08),
      ),
      backgroundColor: spec.card.withValues(alpha: .8),
      showCheckmark: false,
    );
  }

  Widget _creatorCard(AppThemeSpec spec, _VideoCreator creator) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      radius: 18,
      onTap: () => _openCreator(creator),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: spec.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: spec.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creator.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final tag in creator.tags)
                      Pill(label: tag, color: spec.secondary),
                  ],
                ),
                if (creator.audience.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    '适合：${creator.audience}',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              color: spec.textSecondary,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCategory {
  final String id;
  final String name;
  final List<_VideoCreator> items;

  const _VideoCategory({
    required this.id,
    required this.name,
    required this.items,
  });
}

class _VideoCreator {
  final String id;
  final String name;
  final List<String> tags;
  final String audience;
  final String bvid;

  const _VideoCreator({
    required this.id,
    required this.name,
    required this.tags,
    required this.audience,
    required this.bvid,
  });
}
