import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../services/bilibili_service.dart';
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
  static const String _introPreferenceKey = 'video_intro_hidden';

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

  final BilibiliService _bilibili = BilibiliService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCreators = <String>{};

  List<_VideoCategory> _categories = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _introVisible = true;
  String? _error;
  String _selected = '全部';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _introVisible = !(prefs.getBool(_introPreferenceKey) ?? false);
    });
  }

  Future<void> _hideIntro() async {
    setState(() => _introVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introPreferenceKey, true);
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
          final midValue = int.tryParse(mid ?? '');
          if (mid == null || bvid == null || midValue == null) continue;
          final name = _displayNames[id] ?? item['name'] as String;
          items.add(
            _VideoCreator(
              id: id,
              name: name,
              tags: (item['tags'] as List<dynamic>? ?? const [])
                  .map((tag) => tag.toString())
                  .toList(),
              audience: item['audience'] as String? ?? '',
              mid: midValue,
              videos: [
                BilibiliVideo(
                  bvid: bvid,
                  title: '精选跟练视频',
                  author: name,
                  duration: '',
                  play: 0,
                ),
              ],
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
      unawaited(_refreshVideos(_allCreators));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '视频合集加载失败，请稍后重试。';
        _loading = false;
      });
    }
  }

  List<_VideoCreator> get _allCreators =>
      _categories.expand((category) => category.items).toList();

  int get _totalCreators =>
      _categories.fold(0, (sum, category) => sum + category.items.length);

  int get _totalVideos => _categories.fold(
        0,
        (sum, category) =>
            sum +
            category.items
                .fold(0, (inner, creator) => inner + creator.videos.length),
      );

  List<_VideoCategory> get _visibleCategories {
    if (_selected == '全部') return _categories;
    return _categories.where((category) => category.id == _selected).toList();
  }

  Future<void> _refreshVideos(List<_VideoCreator> creators) async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);
    for (final creator in creators) {
      if (!mounted) return;
      final videos = await _bilibili.fetchCreatorVideos(
        query: '${creator.name} 健身',
        mid: creator.mid,
        limit: 6,
      );
      if (!mounted) return;
      if (videos.isNotEmpty) {
        setState(() => creator.videos = videos);
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    if (mounted) setState(() => _refreshing = false);
  }

  void _refreshAll() {
    if (_refreshing) return;
    unawaited(_refreshVideos(_allCreators));
  }

  void _openVideo(_VideoCreator creator, BilibiliVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BilibiliPlayerPage(
          name: creator.name,
          bvid: video.bvid,
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
                '每次进入页面会在后台静默刷新各 UP 主的视频列表；点击视频即可在应用内由 B 站播放器直接播放，不缓存、不代理。',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 12.5,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '支持按 UP 主名称、标签或视频标题搜索。仅保留已确认可播放视频的 UP 主。',
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
            tooltip: '刷新视频',
            onPressed: _refreshing ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
    final query = _query.trim().toLowerCase();
    final sections = <({_VideoCategory category, List<_VideoEntry> entries})>[];
    for (final category in categories) {
      final entries = <_VideoEntry>[];
      for (final creator in category.items) {
        final creatorText = [
          creator.name,
          ...creator.tags,
          creator.audience,
        ].join(' ').toLowerCase();
        final creatorMatches = query.isEmpty || creatorText.contains(query);
        final matchedVideos = creatorMatches
            ? creator.videos
            : creator.videos
                .where(
                  (video) =>
                      video.title.toLowerCase().contains(query) ||
                      video.author.toLowerCase().contains(query),
                )
                .toList();
        if (creatorMatches || matchedVideos.isNotEmpty) {
          entries.add(
            _VideoEntry(creator: creator, videos: matchedVideos),
          );
        }
      }
      if (entries.isNotEmpty) {
        sections.add((category: category, entries: entries));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (_introVisible) ...[
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
                        '$_totalCreators 位 UP 主 · $_totalVideos 个视频',
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _hideIntro,
                  tooltip: '关闭',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: spec.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _searchField(spec),
        const SizedBox(height: 12),
        Text(
          '按训练目标分类，点击视频在应用内播放。',
          style: TextStyle(
            color: spec.textSecondary,
            fontSize: 11.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
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
        if (_refreshing) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: spec.textPrimary.withValues(alpha: .05),
              color: spec.primary,
            ),
          ),
        ],
        const SizedBox(height: 4),
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: GlassPanel(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: spec.textSecondary,
                    size: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '没有找到相关 UP 主或视频',
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '试试更短的关键词，或清空搜索。',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final section in sections) ...[
            SectionHeader(
              title: section.category.name,
              subtitle: '${section.entries.length} 位 UP 主',
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
            ),
            for (final entry in section.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _creatorCard(
                  spec,
                  entry.creator,
                  entry.videos,
                  searching: query.isNotEmpty,
                ),
              ),
          ],
      ],
    );
  }

  Widget _searchField(AppThemeSpec spec) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim()),
      style: TextStyle(
        color: spec.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: '搜索 UP 主 / 视频',
        hintStyle: TextStyle(color: spec.textSecondary, fontSize: 12),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: spec.textSecondary,
          size: 20,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                tooltip: '清空搜索',
                icon: Icon(
                  Icons.close_rounded,
                  color: spec.textSecondary,
                  size: 18,
                ),
              ),
        isDense: true,
        filled: true,
        fillColor: spec.textPrimary.withValues(alpha: .04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: spec.textPrimary.withValues(alpha: .08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: spec.textPrimary.withValues(alpha: .08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: spec.primary.withValues(alpha: .65)),
        ),
      ),
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

  Widget _creatorCard(
    AppThemeSpec spec,
    _VideoCreator creator,
    List<BilibiliVideo> videos, {
    required bool searching,
  }) {
    final expanded = searching || _expandedCreators.contains(creator.id);
    final visible = expanded ? videos : videos.take(2).toList();
    final hasMore = !searching && videos.length > 2;

    void toggleExpanded() {
      if (!hasMore) return;
      setState(() {
        if (expanded) {
          _expandedCreators.remove(creator.id);
        } else {
          _expandedCreators.add(creator.id);
        }
      });
    }

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasMore ? toggleExpanded : null,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${videos.length} 个视频',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasMore)
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: spec.textSecondary,
                        size: 19,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final video in visible) _videoTile(spec, creator, video),
            if (hasMore)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: toggleExpanded,
                  child: Text(
                    expanded ? '收起' : '展开全部 ${videos.length} 个视频',
                    style: TextStyle(
                      color: spec.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '正在后台获取视频…',
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _videoTile(
    AppThemeSpec spec,
    _VideoCreator creator,
    BilibiliVideo video,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openVideo(creator, video),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: spec.textPrimary.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: spec.textPrimary.withValues(alpha: .06),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: spec.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    video.title.isEmpty ? '未命名视频' : video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (video.duration.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    video.duration,
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
  final int mid;
  List<BilibiliVideo> videos;

  _VideoCreator({
    required this.id,
    required this.name,
    required this.tags,
    required this.audience,
    required this.mid,
    required this.videos,
  });
}

class _VideoEntry {
  final _VideoCreator creator;
  final List<BilibiliVideo> videos;

  const _VideoEntry({required this.creator, required this.videos});
}
