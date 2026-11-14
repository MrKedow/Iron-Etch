import 'package:fitness_tracker/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy AI data scopes migrate to granular scopes', () async {
    SharedPreferences.setMockInitialValues({
      'ai_data_scopes': ['profile', 'recent', 'feelings'],
    });

    final settings = SettingsProvider();
    await settings.ready;

    expect(
      settings.aiDataScopes,
      containsAll([
        'profile_basic',
        'profile_body',
        'recent_strength',
        'recent_cardio',
        'feelings',
      ]),
    );
    expect(settings.aiDataScopes, isNot(contains('summary_strength')));
  });
}
