import 'package:fitness_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dynamic counts and units are localized', () {
    final en = AppLocalizations(const Locale('en', 'US'));
    final ja = AppLocalizations(const Locale('ja', 'JP'));
    final ko = AppLocalizations(const Locale('ko', 'KR'));
    final ru = AppLocalizations(const Locale('ru', 'RU'));

    expect(en.t('第 3 次训练 · 4 个动作 · 40 分钟'), 'Session 3 · 4 exercises · 40 min');
    expect(en.t('3 组'), '3 sets');
    expect(en.t('完成度 82%'), '82% complete');
    expect(ja.t('40 分钟'), '40分');
    expect(ko.t('3 组'), '3세트');
    expect(ru.t('3 组'), '3 подх.');
  });
}
