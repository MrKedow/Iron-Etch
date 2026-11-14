import 'package:fitness_tracker/services/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selected Google font is applied to the text theme', () {
    final theme = AppFonts.apply(
      ThemeData(
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        dialogTheme: const DialogThemeData(
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      fontId: 'ma-shan-zheng',
    );

    expect(theme.textTheme.bodyMedium?.fontFamily, contains('MaShanZheng'));
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback,
        contains('MaShanZheng'));
    expect(
        theme.appBarTheme.titleTextStyle?.fontFamily, contains('MaShanZheng'));
    expect(
        theme.dialogTheme.titleTextStyle?.fontFamily, contains('MaShanZheng'));
  });
}
