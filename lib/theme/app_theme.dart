import 'package:flutter/material.dart';

class AppThemeSpec {
  final String id;
  final String name;
  final String subtitle;
  final String emoji;
  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final List<Color> gradient;
  final bool glass;
  final double radius;

  const AppThemeSpec({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.gradient,
    this.glass = false,
    this.radius = 22,
  });

  bool get isDark => brightness == Brightness.dark;

  LinearGradient get heroGradient => LinearGradient(
        colors: gradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  ThemeData toThemeData({bool transparentBackground = false}) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: _onColor(primary),
      secondary: secondary,
      onSecondary: _onColor(secondary),
      error: const Color(0xFFFF5A5F),
      onError: Colors.white,
      surface: transparentBackground ? Colors.transparent : surface,
      onSurface: textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          transparentBackground ? Colors.transparent : background,
      canvasColor: transparentBackground ? Colors.transparent : surface,
      cardColor: transparentBackground ? card.withValues(alpha: 0.82) : card,
      dividerColor: textPrimary.withValues(alpha: 0.08),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: textPrimary.withValues(alpha: 0.08)),
    );

    return base.copyWith(
      primaryColor: primary,
      appBarTheme: AppBarTheme(
        backgroundColor:
            transparentBackground ? Colors.transparent : background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: transparentBackground ? card.withValues(alpha: 0.82) : card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: textPrimary.withValues(alpha: 0.06)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: transparentBackground
            ? background.withValues(alpha: 0.94)
            : surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius + 4)),
        titleTextStyle: TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(color: textSecondary, height: 1.5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: transparentBackground
            ? background.withValues(alpha: 0.97)
            : surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _onColor(primary),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _onColor(primary),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: textPrimary.withValues(alpha: 0.16)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: textPrimary.withValues(alpha: isDark ? 0.055 : 0.045),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF5A5F)),
        ),
        labelStyle: TextStyle(color: textSecondary, fontSize: 13),
        hintStyle:
            TextStyle(color: textSecondary.withValues(alpha: 0.65)),
        suffixStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: textPrimary, displayColor: textPrimary)
          .copyWith(
            bodyLarge: TextStyle(
                color: textPrimary, fontSize: 15, height: 1.55),
            bodyMedium: TextStyle(
                color: textSecondary, fontSize: 13.5, height: 1.55),
            titleLarge: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800),
            titleMedium: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700),
            labelLarge: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: textPrimary.withValues(alpha: 0.06),
        selectedColor: primary.withValues(alpha: 0.18),
        side: BorderSide(color: textPrimary.withValues(alpha: 0.06)),
        labelStyle: TextStyle(
            color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF252B36) : Colors.black87,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme:
          DividerThemeData(color: textPrimary.withValues(alpha: 0.07)),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _onColor(primary);
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primary,
        headerForegroundColor: _onColor(primary),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26)),
      ),
    );
  }

  static Color _onColor(Color color) {
    return color.computeLuminance() > .6 ? const Color(0xFF101216) : Colors.white;
  }
}

class AppThemes {
  static const ironForge = AppThemeSpec(
    id: 'iron_forge',
    name: '铁铸黑金',
    subtitle: '铁馆灯光 · 力量与荣誉',
    emoji: '🏋️',
    brightness: Brightness.dark,
    primary: Color(0xFFE4B363),
    secondary: Color(0xFFE76F51),
    accent: Color(0xFF6EE7F9),
    background: Color(0xFF080B10),
    surface: Color(0xFF11161E),
    card: Color(0xFF151C26),
    textPrimary: Color(0xFFF4F1EA),
    textSecondary: Color(0xFF9BA7B7),
    gradient: [Color(0xFF1B2330), Color(0xFF0A0D13), Color(0xFF3B2B14)],
  );

  static const mountainMist = AppThemeSpec(
    id: 'mountain_mist',
    name: '远山青黛',
    subtitle: '青绿渐变 · 呼吸感留白',
    emoji: '⛰️',
    brightness: Brightness.dark,
    primary: Color(0xFF4FD1C5),
    secondary: Color(0xFF2E8B9E),
    accent: Color(0xFFA7F3D0),
    background: Color(0xFF0C1820),
    surface: Color(0xFF12222D),
    card: Color(0xFF172A36),
    textPrimary: Color(0xFFEEF7F7),
    textSecondary: Color(0xFF91A9B2),
    gradient: [Color(0xFF12313A), Color(0xFF0A171E), Color(0xFF1F4D4A)],
  );

  static const neonPulse = AppThemeSpec(
    id: 'neon_pulse',
    name: '赛博霓虹',
    subtitle: '紫青脉冲 · 未来训练舱',
    emoji: '⚡',
    brightness: Brightness.dark,
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFF22D3EE),
    accent: Color(0xFFF472B6),
    background: Color(0xFF080714),
    surface: Color(0xFF121026),
    card: Color(0xFF17142E),
    textPrimary: Color(0xFFF2F0FF),
    textSecondary: Color(0xFF9D97C4),
    gradient: [Color(0xFF241A52), Color(0xFF0B0918), Color(0xFF073B4C)],
  );

  static const forest = AppThemeSpec(
    id: 'forest',
    name: '森野呼吸',
    subtitle: '苔绿木质 · 自然恢复力',
    emoji: '🌿',
    brightness: Brightness.dark,
    primary: Color(0xFF7BAA6E),
    secondary: Color(0xFFB08968),
    accent: Color(0xFFE9C46A),
    background: Color(0xFF0D1410),
    surface: Color(0xFF152019),
    card: Color(0xFF1A2A21),
    textPrimary: Color(0xFFF0F5EB),
    textSecondary: Color(0xFFA1B5A5),
    gradient: [Color(0xFF1C3326), Color(0xFF0B120E), Color(0xFF3A2E1F)],
  );

  static const sakura = AppThemeSpec(
    id: 'sakura',
    name: '樱雾晨光',
    subtitle: '奶油粉白 · 温柔但有力量',
    emoji: '🌸',
    brightness: Brightness.light,
    primary: Color(0xFFD96C8A),
    secondary: Color(0xFF9B7EDE),
    accent: Color(0xFF4ECDC4),
    background: Color(0xFFFFF7F8),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2B2228),
    textSecondary: Color(0xFF8A7A82),
    gradient: [Color(0xFFFFE4EC), Color(0xFFFFF8FA), Color(0xFFEDE7FF)],
  );

  static const porcelain = AppThemeSpec(
    id: 'porcelain',
    name: '珠玉白',
    subtitle: '汉白玉渐变 · 温润护眼',
    emoji: '🤍',
    brightness: Brightness.light,
    primary: Color(0xFF3F6CA8),
    secondary: Color(0xFF6B8FC7),
    accent: Color(0xFFE0A458),
    background: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1D2530),
    textSecondary: Color(0xFF6B7688),
    gradient: [Color(0xFFFDFBF7), Color(0xFFF1F4F9), Color(0xFFE4EDF9)],
  );

  static const sunset = AppThemeSpec(
    id: 'sunset',
    name: '落日熔金',
    subtitle: '橙红渐变 · 热血燃烧',
    emoji: '🌇',
    brightness: Brightness.dark,
    primary: Color(0xFFFFA24C),
    secondary: Color(0xFFFF5E5B),
    accent: Color(0xFFFFD166),
    background: Color(0xFF140D0A),
    surface: Color(0xFF211511),
    card: Color(0xFF2A1A14),
    textPrimary: Color(0xFFFFF6EC),
    textSecondary: Color(0xFFC0A394),
    gradient: [Color(0xFF4A1F14), Color(0xFF160D09), Color(0xFF7A3517)],
  );

  static const materialYou = AppThemeSpec(
    id: 'material_you',
    name: '莫奈晨雾',
    subtitle: 'Material 3 · 开源调色板',
    emoji: '🎨',
    brightness: Brightness.light,
    primary: Color(0xFF386A5C),
    secondary: Color(0xFF7A8F6B),
    accent: Color(0xFF9C6B4E),
    background: Color(0xFFF7FBF7),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF191C1A),
    textSecondary: Color(0xFF5F6B64),
    gradient: [Color(0xFFDCEFE6), Color(0xFFFDFBF4), Color(0xFFE8E3F7)],
  );

  static const midnightGlass = AppThemeSpec(
    id: 'midnight_glass',
    name: '午夜琉璃',
    subtitle: '半透明玻璃 · 沉浸式光影',
    emoji: '🫧',
    brightness: Brightness.dark,
    primary: Color(0xFF7DD3FC),
    secondary: Color(0xFFC4B5FD),
    accent: Color(0xFFF9A8D4),
    background: Color(0xFF070B12),
    surface: Color(0xFF0E1520),
    card: Color(0xFF101A27),
    textPrimary: Color(0xFFF3F8FF),
    textSecondary: Color(0xFF93A4B8),
    gradient: [Color(0xFF14293D), Color(0xFF070B12), Color(0xFF2A1638)],
    glass: true,
  );

  static const List<AppThemeSpec> all = [
    ironForge,
    mountainMist,
    neonPulse,
    sunset,
    forest,
    midnightGlass,
    sakura,
    porcelain,
    materialYou,
  ];

  static AppThemeSpec byId(String? id) {
    return all.firstWhere(
      (theme) => theme.id == id,
      orElse: () => ironForge,
    );
  }
}
