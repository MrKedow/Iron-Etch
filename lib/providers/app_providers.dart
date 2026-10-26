import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(String initialThemeId)
      : _themeId = AppThemes.byId(initialThemeId).id {
    _loadCustomBackground();
  }

  String _themeId;
  String? _customBackgroundPath;

  String get themeId => _themeId;
  AppThemeSpec get currentSpec => AppThemes.byId(_themeId);
  String? get customBackgroundPath => _customBackgroundPath;
  bool get hasCustomBackground =>
      _customBackgroundPath != null && _customBackgroundPath!.trim().isNotEmpty;

  ThemeData get currentTheme =>
      currentSpec.toThemeData(transparentBackground: hasCustomBackground);

  Future<void> setTheme(String id) async {
    if (_themeId == id) return;
    _themeId = AppThemes.byId(id).id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme_id', _themeId);
    await prefs.remove('selected_theme');
    notifyListeners();
  }

  Future<void> _loadCustomBackground() async {
    final prefs = await SharedPreferences.getInstance();
    _customBackgroundPath = prefs.getString('theme_custom_background');
    notifyListeners();
  }

  Future<void> setCustomBackground(String path) async {
    _customBackgroundPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_custom_background', path);
    notifyListeners();
  }

  Future<void> clearCustomBackground() async {
    _customBackgroundPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('theme_custom_background');
    notifyListeners();
  }
}

class SettingsProvider extends ChangeNotifier {
  static const String defaultAiEndpoint =
      'https://opencode.ai/inference/openai/v1/chat/completions';
  static const String defaultAiModel = 'big-pickle';

  static const List<String> quotes = [
    '每一次努力都值得记录',
    '杠铃不会说谎，时间会给你答案',
    '汗水是肌肉写给未来的情书',
    '今天多举一公斤，明天多一分底气',
    '把自律刻进骨子里，把力量举过头顶',
    '训练没有捷径，只有一次次重复',
    '你举起的不只是重量，还有更好的自己',
    '别等状态，开始训练状态就来了',
    '铁片冰冷，身体滚烫',
    '慢一点没关系，别停下来',
    '动作标准，比数字漂亮更重要',
    '坚持不是口号，是今天真的来了',
  ];

  static const List<String> statusEmojis = [
    '🔥',
    '💪',
    '🏋️',
    '⚡',
    '🦾',
    '🥇',
    '🌙',
    '🌿',
    '☕',
    '🧊',
    '🚀',
    '🎯',
  ];

  String _nickname = '铁友';
  String _trainingGoal = '增肌';
  String _experience = '进阶';
  double _bodyWeight = 70;
  int _weeklyGoal = 4;
  String _weightUnit = 'kg';
  int _restSeconds = 90;
  bool _haptics = true;
  bool _remindersEnabled = false;
  String _reminderTime = '20:00';

  bool _aiEnabled = true;
  String _aiEndpoint = defaultAiEndpoint;
  String _aiModel = defaultAiModel;
  String _aiApiKey = '';

  String _statusEmoji = '🔥';
  String _statusText = '今天的铁，也要镌刻进身体里';
  String? _statusImagePath;
  int _statusTone = 0;
  int _statusMotion = 0;

  String get nickname => _nickname;
  String get trainingGoal => _trainingGoal;
  String get experience => _experience;
  double get bodyWeight => _bodyWeight;
  int get weeklyGoal => _weeklyGoal;
  String get weightUnit => _weightUnit;
  int get restSeconds => _restSeconds;
  bool get haptics => _haptics;
  bool get remindersEnabled => _remindersEnabled;
  String get reminderTime => _reminderTime;

  bool get aiEnabled => _aiEnabled;
  String get aiEndpoint => _aiEndpoint;
  String get aiModel => _aiModel;
  String get aiApiKey => _aiApiKey;
  bool get hasAiKey => _aiApiKey.trim().isNotEmpty;

  String get statusEmoji => _statusEmoji;
  String get statusText => _statusText;
  String? get statusImagePath => _statusImagePath;
  int get statusTone => _statusTone;
  int get statusMotion => _statusMotion;

  String get todayQuote {
    final index =
        DateTime.now().difference(DateTime(2020)).inDays % quotes.length;
    return quotes[index.abs() % quotes.length];
  }

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString('profile_nickname') ?? '铁友';
    _trainingGoal = prefs.getString('profile_goal') ?? '增肌';
    _experience = prefs.getString('profile_experience') ?? '进阶';
    _bodyWeight = prefs.getDouble('profile_body_weight') ?? 70;
    _weeklyGoal = prefs.getInt('training_weekly_goal') ?? 4;
    _weightUnit = prefs.getString('training_weight_unit') ?? 'kg';
    _restSeconds = prefs.getInt('training_rest_seconds') ?? 90;
    _haptics = prefs.getBool('training_haptics') ?? true;
    _remindersEnabled = prefs.getBool('reminder_enabled') ?? false;
    _reminderTime = prefs.getString('reminder_time') ?? '20:00';

    _aiEnabled = prefs.getBool('ai_enabled') ?? true;
    _aiEndpoint = prefs.getString('ai_endpoint') ?? defaultAiEndpoint;
    _aiModel = prefs.getString('ai_model') ?? defaultAiModel;
    _aiApiKey = prefs.getString('ai_api_key') ?? '';

    _statusEmoji = prefs.getString('status_emoji') ?? '🔥';
    _statusText = prefs.getString('status_text') ?? '今天的铁，也要镌刻进身体里';
    _statusImagePath = prefs.getString('status_image_path');
    _statusTone = prefs.getInt('status_tone') ?? 0;
    _statusMotion = prefs.getInt('status_motion') ?? 0;
    notifyListeners();
  }

  Future<void> _persist(String key, Object? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  Future<void> setNickname(String value) async {
    _nickname = value.trim().isEmpty ? '铁友' : value.trim();
    await _persist('profile_nickname', _nickname);
    notifyListeners();
  }

  Future<void> setTrainingGoal(String value) async {
    _trainingGoal = value;
    await _persist('profile_goal', value);
    notifyListeners();
  }

  Future<void> setExperience(String value) async {
    _experience = value;
    await _persist('profile_experience', value);
    notifyListeners();
  }

  Future<void> setBodyWeight(double value) async {
    _bodyWeight = value.clamp(20, 350);
    await _persist('profile_body_weight', _bodyWeight);
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int value) async {
    _weeklyGoal = value.clamp(1, 14);
    await _persist('training_weekly_goal', _weeklyGoal);
    notifyListeners();
  }

  Future<void> setWeightUnit(String value) async {
    _weightUnit = value;
    await _persist('training_weight_unit', value);
    notifyListeners();
  }

  Future<void> setRestSeconds(int value) async {
    _restSeconds = value.clamp(15, 600);
    await _persist('training_rest_seconds', _restSeconds);
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    await _persist('training_haptics', value);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool value) async {
    _remindersEnabled = value;
    await _persist('reminder_enabled', value);
    notifyListeners();
  }

  Future<void> setReminderTime(String value) async {
    _reminderTime = value;
    await _persist('reminder_time', value);
    notifyListeners();
  }

  Future<void> setAiEnabled(bool value) async {
    _aiEnabled = value;
    await _persist('ai_enabled', value);
    notifyListeners();
  }

  Future<void> setAiConfig({
    String? endpoint,
    String? model,
    String? apiKey,
  }) async {
    if (endpoint != null) {
      _aiEndpoint =
          endpoint.trim().isEmpty ? defaultAiEndpoint : endpoint.trim();
      await _persist('ai_endpoint', _aiEndpoint);
    }
    if (model != null) {
      _aiModel = model.trim().isEmpty ? defaultAiModel : model.trim();
      await _persist('ai_model', _aiModel);
    }
    if (apiKey != null) {
      _aiApiKey = apiKey.trim();
      await _persist('ai_api_key', _aiApiKey);
    }
    notifyListeners();
  }

  Future<void> setStatus({
    String? emoji,
    String? text,
    String? imagePath,
    bool clearImage = false,
    int? tone,
    int? motion,
  }) async {
    if (emoji != null) {
      _statusEmoji = emoji;
      await _persist('status_emoji', emoji);
    }
    if (text != null) {
      _statusText = text.trim().isEmpty ? todayQuote : text.trim();
      await _persist('status_text', _statusText);
    }
    if (clearImage) {
      _statusImagePath = null;
      await _persist('status_image_path', null);
    } else if (imagePath != null) {
      _statusImagePath = imagePath;
      await _persist('status_image_path', imagePath);
    }
    if (tone != null) {
      _statusTone = tone;
      await _persist('status_tone', tone);
    }
    if (motion != null) {
      _statusMotion = motion;
      await _persist('status_motion', motion);
    }
    notifyListeners();
  }
}
