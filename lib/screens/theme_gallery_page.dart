import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class ThemeGalleryPage extends StatelessWidget {
  const ThemeGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final spec = themeProvider.currentSpec;
    final customPath = themeProvider.customBackgroundPath;
    final hasCustom = customPath != null && File(customPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题工坊'),
        actions: [
          IconButton(
            tooltip: '恢复默认',
            onPressed: () async {
              await themeProvider.clearCustomBackground();
              await themeProvider.setTheme(AppThemes.ironForge.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复铁铸黑金主题')),
                );
              }
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
        children: [
          FadeSlideIn(
            child: GlassPanel(
              gradient: spec.heroGradient,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(spec.emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spec.name,
                              style: TextStyle(
                                color: spec.onHero,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              spec.subtitle,
                              style: TextStyle(
                                color: spec.onHeroMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Pill(
                        label: spec.isDark ? '深色' : '浅色',
                        color: spec.onHero,
                        icon: Icons.contrast_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _colorDot(spec, spec.primary),
                      _colorDot(spec, spec.secondary),
                      _colorDot(spec, spec.accent),
                      _colorDot(spec, spec.card),
                      const Spacer(),
                      Text(
                        hasCustom ? '叠加自定义背景' : '点击下方主题实时切换',
                        style: TextStyle(
                          color: spec.onHero.withValues(alpha: .62),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: '内置主题',
            subtitle: '参考开源 Material 3 调色板与流行影音应用设计',
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppThemes.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: .78,
            ),
            itemBuilder: (context, index) {
              final theme = AppThemes.all[index];
              final selected = theme.id == themeProvider.themeId;
              return FadeSlideIn(
                index: index,
                child: _ThemeCard(
                  spec: theme,
                  selected: selected,
                  onTap: () => themeProvider.setTheme(theme.id),
                ),
              );
            },
          ),
          const SectionHeader(
            title: '自定义图片主题',
            subtitle: '从相册导入一张图片，作为整个应用的沉浸式背景',
          ),
          FadeSlideIn(
            child: GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 152,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: spec.textPrimary.withValues(alpha: .04),
                      image: hasCustom
                          ? DecorationImage(
                              image: FileImage(File(customPath)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(
                        color: spec.textPrimary.withValues(alpha: .08),
                      ),
                    ),
                    child: hasCustom
                        ? Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Pill(
                                label: '已启用',
                                icon: Icons.check_circle_rounded,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wallpaper_rounded,
                                size: 38,
                                color: spec.textSecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '还没有导入图片',
                                style: TextStyle(
                                  color: spec.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 90,
                            );
                            if (picked == null) return;
                            final dir =
                                await getApplicationDocumentsDirectory();
                            final target =
                                '${dir.path}/theme_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await File(picked.path).copy(target);
                            await themeProvider.setCustomBackground(target);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('图片主题已应用')),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 19),
                          label: Text(hasCustom ? '更换图片' : '导入图片'),
                        ),
                      ),
                      if (hasCustom) ...[
                        const SizedBox(width: 10),
                        IconButton.outlined(
                          onPressed: () async {
                            await themeProvider.clearCustomBackground();
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          tooltip: '移除自定义背景',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '主题会同步改变背景、卡片、按钮、输入框与弹窗风格。图片主题会自动叠加暗色蒙层，保证文字清晰可读。',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 11.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(AppThemeSpec spec, Color color) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: spec.onHero.withValues(alpha: .35)),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: spec.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color:
                selected ? spec.primary : Colors.white.withValues(alpha: .08),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: spec.primary.withValues(alpha: .35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(spec.emoji, style: const TextStyle(fontSize: 20)),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: spec.primary),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: spec.card.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: spec.textPrimary.withValues(alpha: .06),
                      ),
                    ),
                    padding: const EdgeInsets.all(9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: spec.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(
                                color: spec.textPrimary.withValues(alpha: .4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          height: 5,
                          width: 70,
                          decoration: BoxDecoration(
                            color: spec.textPrimary.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    spec.name,
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: spec.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
