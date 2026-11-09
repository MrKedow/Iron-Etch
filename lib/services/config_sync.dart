import 'package:shared_preferences/shared_preferences.dart';

enum ConfigSyncScope {
  profile,
  training,
  status,
  theme,
  ai,
  reading,
  reminder,
  images,
  other,
}

extension ConfigSyncScopeInfo on ConfigSyncScope {
  String get label => switch (this) {
        ConfigSyncScope.profile => '个人资料',
        ConfigSyncScope.training => '训练与目标',
        ConfigSyncScope.status => '状态卡片',
        ConfigSyncScope.theme => '主题与外观',
        ConfigSyncScope.ai => 'AI 教练',
        ConfigSyncScope.reading => '阅读与书库',
        ConfigSyncScope.reminder => '训练提醒',
        ConfigSyncScope.images => '自定义图片',
        ConfigSyncScope.other => '其他应用数据',
      };

  String get description => switch (this) {
        ConfigSyncScope.profile => '昵称、身高、体重、体脂、年龄、性别等',
        ConfigSyncScope.training => '每周目标、重量单位、组间休息、触感、拍照入口',
        ConfigSyncScope.status => '状态卡片的文字、色调、动效与电量',
        ConfigSyncScope.theme => '当前主题、深浅模式、自定义背景设置',
        ConfigSyncScope.ai => 'AI 接口、模型、提示词与 API Key',
        ConfigSyncScope.reading => '阅读进度、字体、背景、笔记、书库排序与材质',
        ConfigSyncScope.reminder => '提醒开关与提醒时间',
        ConfigSyncScope.images => '头像、状态图片与主题背景图片文件',
        ConfigSyncScope.other => '未归类的其他本地配置项',
      };
}

class ConfigSyncService {
  const ConfigSyncService._();

  static const String scopePrefKey = 'cloud_sync_scopes';

  static const Set<String> fileKeys = {
    'theme_custom_background',
    'profile_avatar_path',
    'status_image_path',
  };

  static const Map<String, String> fileRemotePrefixes = {
    'theme_custom_background': 'config_background',
    'profile_avatar_path': 'config_avatar',
    'status_image_path': 'config_status',
  };

  static const List<ConfigSyncScope> allScopes = ConfigSyncScope.values;

  static const Set<ConfigSyncScope> defaultScopes = {
    ConfigSyncScope.profile,
    ConfigSyncScope.training,
    ConfigSyncScope.status,
    ConfigSyncScope.theme,
    ConfigSyncScope.ai,
    ConfigSyncScope.reading,
    ConfigSyncScope.reminder,
    ConfigSyncScope.images,
    ConfigSyncScope.other,
  };

  static Future<Set<ConfigSyncScope>> loadScopes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(scopePrefKey);
    if (saved == null) return Set<ConfigSyncScope>.from(defaultScopes);
    final scopes = <ConfigSyncScope>{};
    for (final id in saved) {
      for (final scope in ConfigSyncScope.values) {
        if (scope.name == id) scopes.add(scope);
      }
    }
    return scopes;
  }

  static Future<void> saveScopes(Set<ConfigSyncScope> scopes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      scopePrefKey,
      scopes.map((scope) => scope.name).toList(),
    );
  }

  static bool _isExcluded(String key) =>
      key.startsWith('nutstore_') ||
      key == 'workout_records' ||
      key == 'last_export_path' ||
      key == scopePrefKey;

  static ConfigSyncScope scopeOf(String key) {
    if (key.startsWith('profile_')) return ConfigSyncScope.profile;
    if (key.startsWith('training_') ||
        key.startsWith('dashboard_') ||
        key == 'first_workout_date') {
      return ConfigSyncScope.training;
    }
    if (key.startsWith('status_')) return ConfigSyncScope.status;
    if (key == 'selected_theme' ||
        key == 'selected_theme_id' ||
        key == 'theme_mode' ||
        key == 'theme_custom_background') {
      return ConfigSyncScope.theme;
    }
    if (key.startsWith('ai_')) return ConfigSyncScope.ai;
    if (key.startsWith('epub_') || key.startsWith('library_')) {
      return ConfigSyncScope.reading;
    }
    if (key.startsWith('reminder_')) return ConfigSyncScope.reminder;
    return ConfigSyncScope.other;
  }

  static Map<String, dynamic>? _encode(Object? value) {
    if (value == null) return null;
    if (value is List<String>) return {'t': 'list', 'v': value};
    if (value is bool) return {'t': 'bool', 'v': value};
    if (value is int) return {'t': 'int', 'v': value};
    if (value is double) return {'t': 'double', 'v': value};
    return {'t': 'string', 'v': value.toString()};
  }

  static Future<Map<String, dynamic>> buildPayload(
    Set<ConfigSyncScope> scopes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_isExcluded(key)) continue;
      final scope = scopeOf(key);
      if (!scopes.contains(scope)) continue;
      if (fileKeys.contains(key) && !scopes.contains(ConfigSyncScope.images)) {
        continue;
      }
      final encoded = _encode(prefs.get(key));
      if (encoded != null) prefsMap[key] = encoded;
    }
    return {
      'format': 2,
      'scopes': scopes.map((scope) => scope.name).toList(),
      'prefs': prefsMap,
    };
  }

  static Future<int> applyPayload(
    Map<String, dynamic> data,
    Set<ConfigSyncScope> scopes,
  ) async {
    final rawPrefs = data['format'] == 2 && data['prefs'] is Map
        ? Map<String, dynamic>.from(data['prefs'] as Map)
        : data;
    final prefs = await SharedPreferences.getInstance();
    var applied = 0;
    for (final entry in rawPrefs.entries) {
      final key = entry.key;
      if (_isExcluded(key)) continue;
      final scope = scopeOf(key);
      if (!scopes.contains(scope)) continue;
      if (fileKeys.contains(key) && !scopes.contains(ConfigSyncScope.images)) {
        continue;
      }
      final value = entry.value;
      if (value is! Map) continue;
      final type = value['t']?.toString();
      final v = value['v'];
      switch (type) {
        case 'list':
          if (v is List) {
            await prefs.setStringList(
              key,
              v.map((item) => item.toString()).toList(),
            );
            applied++;
          }
        case 'bool':
          if (v is bool) {
            await prefs.setBool(key, v);
            applied++;
          }
        case 'int':
          if (v is int) {
            await prefs.setInt(key, v);
            applied++;
          }
        case 'double':
          if (v is num) {
            await prefs.setDouble(key, v.toDouble());
            applied++;
          }
        case 'string':
          await prefs.setString(key, v?.toString() ?? '');
          applied++;
      }
    }
    return applied;
  }
}
