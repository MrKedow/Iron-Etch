import 'package:fitness_tracker/services/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('system font keeps the base theme unchanged', () {
    final base = ThemeData();
    final theme = AppFonts.apply(base, fontId: 'system');
    expect(identical(theme, base), isTrue);
  });

  test('downloadable font is not applied until it is loaded', () {
    final base = ThemeData(
      appBarTheme: const AppBarTheme(
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
    final theme = AppFonts.apply(base, fontId: 'ma-shan-zheng');
    expect(
      theme.textTheme.bodyMedium?.fontFamily,
      base.textTheme.bodyMedium?.fontFamily,
    );
    expect(
      theme.appBarTheme.titleTextStyle?.fontFamily,
      base.appBarTheme.titleTextStyle?.fontFamily,
    );
    expect(AppFonts.isLoaded('ma-shan-zheng'), isFalse);
  });

  test('unknown font id resolves to the system option', () {
    expect(appFontById('does-not-exist').id, 'system');
    expect(appFontById(null).isSystem, isTrue);
  });

  test('only bundled options expose a download url', () {
    for (final option in appFontOptions) {
      if (option.isSystem || option.isCustom) {
        expect(option.url, isNull);
      } else {
        expect(option.url, isNotNull);
        expect(option.url, startsWith('https://'));
      }
    }
  });
}
