import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_haptics.dart';
import '../services/work_energy.dart';
import '../theme/app_theme.dart';

class AiModelPreset {
  final String id;
  final String label;
  final bool supportsVision;
  final bool free;

  const AiModelPreset(
    this.id,
    this.label, {
    this.supportsVision = false,
    this.free = false,
  });
}

class AiProviderPreset {
  final String id;
  final String label;
  final String endpoint;
  final String keyHint;
  final String description;
  final bool requiresKey;
  final List<AiModelPreset> models;

  const AiProviderPreset({
    required this.id,
    required this.label,
    required this.endpoint,
    required this.keyHint,
    required this.description,
    required this.models,
    this.requiresKey = true,
  });

  bool get isCustom => id == 'custom';
}

const AiProviderPreset customAiProvider = AiProviderPreset(
  id: 'custom',
  label: '自定义 OpenAI 兼容服务',
  endpoint: '',
  keyHint: 'sk-...',
  description: '手动填写接口地址和模型 ID，适用于任意 OpenAI 兼容服务。',
  models: [
    AiModelPreset('', '手动填写模型 ID'),
  ],
);

const List<AiProviderPreset> builtInAiProviders = [
  AiProviderPreset(
    id: 'opencode',
    label: 'OpenCode Zen',
    endpoint: 'https://opencode.ai/inference/openai/v1/chat/completions',
    keyHint: '可选，留空使用免费模型',
    description: 'OpenCode V2 官方网关，含免费文本模型与视觉模型。',
    requiresKey: false,
    models: [
      AiModelPreset('big-pickle', 'Big Pickle（免费）', free: true),
      AiModelPreset(
          'nemotron-3.5-super-vl-free', 'Nemotron 3.5 Super VL（免费 · 视觉）',
          supportsVision: true, free: true),
      AiModelPreset('deepseek-v4.1-flash-free', 'DeepSeek V4.1 Flash（免费）',
          free: true),
      AiModelPreset('glm-5.3-flash-free', 'GLM-5.3 Flash（免费）', free: true),
      AiModelPreset('minimax-m3.1-flash-free', 'MiniMax M3.1 Flash（免费）',
          free: true),
      AiModelPreset('mimo-v2.6-flash-free', 'MiMo V2.6 Flash（免费）', free: true),
      AiModelPreset('nemotron-3.5-lightning-free', 'Nemotron 3.5 Lightning（免费）',
          free: true),
      AiModelPreset('nemotron-3-ultra-free', 'Nemotron 3 Ultra（免费）',
          free: true),
      AiModelPreset('longcat-2.5-free', 'LongCat 2.5（免费）', free: true),
      AiModelPreset('flint-40b-free', 'Flint 40B（免费）', free: true),
      AiModelPreset('iceman-free', 'Iceman（免费）', free: true),
      AiModelPreset('deepseek-v4.1-flash', 'DeepSeek V4.1 Flash'),
      AiModelPreset('deepseek-v4-pro', 'DeepSeek V4 Pro'),
      AiModelPreset('glm-5.3-flash', 'GLM 5.3 Flash'),
      AiModelPreset('glm-5.3', 'GLM 5.3'),
      AiModelPreset('minimax-m3', 'MiniMax M3'),
      AiModelPreset('kimi-k2.7-code', 'Kimi K2.7 Code'),
      AiModelPreset('kimi-k3', 'Kimi K3'),
      AiModelPreset('qwen3.8-flash', 'Qwen3.8 Flash'),
      AiModelPreset('qwen3.8-max', 'Qwen3.8 Max'),
      AiModelPreset('gemini-3.8-flash', 'Gemini 3.8 Flash'),
      AiModelPreset('claude-sonnet-5', 'Claude Sonnet 5'),
      AiModelPreset('gpt-6.1-sol', 'GPT 6.1 Sol'),
      AiModelPreset('grok-4.7', 'Grok 4.7'),
      AiModelPreset('mistral-large-4', 'Mistral Large 4'),
    ],
  ),
  AiProviderPreset(
    id: 'blockrun',
    label: 'BlockRun',
    endpoint: 'https://blockrun.ai/api/v1/chat/completions',
    keyHint: '可选，留空使用免费通道',
    description: '免费 GPT-OSS 通道，适合日常训练分析。',
    requiresKey: false,
    models: [
      AiModelPreset('nvidia/gpt-oss-20b', 'GPT-OSS 20B（免费）', free: true),
      AiModelPreset('nvidia/gpt-oss-120b', 'GPT-OSS 120B（免费）', free: true),
    ],
  ),
  AiProviderPreset(
    id: 'pollinations',
    label: 'Pollinations',
    endpoint: 'https://text.pollinations.ai/openai',
    keyHint: '可选，留空使用免费通道',
    description: '免登录公共通道，作为免费回退使用。',
    requiresKey: false,
    models: [
      AiModelPreset('gpt-oss-20b', 'GPT-OSS 20B（免费）', free: true),
      AiModelPreset('openai', 'OpenAI（免费）', free: true),
    ],
  ),
  AiProviderPreset(
    id: 'openai',
    label: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/chat/completions',
    keyHint: 'sk-...',
    description: '官方 OpenAI API，需要 API Key。',
    models: [
      AiModelPreset('gpt-5.4-mini', 'GPT-5.4 Mini', supportsVision: true),
      AiModelPreset('gpt-5.4', 'GPT-5.4', supportsVision: true),
      AiModelPreset('gpt-5.4-nano', 'GPT-5.4 Nano', supportsVision: true),
      AiModelPreset('gpt-4.1-mini', 'GPT-4.1 Mini', supportsVision: true),
      AiModelPreset('gpt-4.1', 'GPT-4.1', supportsVision: true),
      AiModelPreset('gpt-4o-mini', 'GPT-4o Mini', supportsVision: true),
      AiModelPreset('o4-mini', 'o4 Mini', supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'anthropic',
    label: 'Anthropic Claude',
    endpoint: 'https://api.anthropic.com/v1/chat/completions',
    keyHint: 'sk-ant-...',
    description: 'Claude 官方 OpenAI 兼容接口。',
    models: [
      AiModelPreset('claude-sonnet-4-5', 'Claude Sonnet 4.5',
          supportsVision: true),
      AiModelPreset('claude-haiku-4-5', 'Claude Haiku 4.5',
          supportsVision: true),
      AiModelPreset('claude-opus-4-5', 'Claude Opus 4.5', supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'google',
    label: 'Google Gemini',
    endpoint:
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    keyHint: 'AIza...',
    description: 'Gemini 官方 OpenAI 兼容接口，速度快、视觉能力强。',
    models: [
      AiModelPreset('gemini-3.5-flash', 'Gemini 3.5 Flash',
          supportsVision: true),
      AiModelPreset('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite',
          supportsVision: true),
      AiModelPreset('gemini-3.1-pro', 'Gemini 3.1 Pro', supportsVision: true),
      AiModelPreset('gemini-3-flash', 'Gemini 3 Flash', supportsVision: true),
      AiModelPreset('gemini-2.5-flash', 'Gemini 2.5 Flash',
          supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'deepseek',
    label: 'DeepSeek',
    endpoint: 'https://api.deepseek.com/v1/chat/completions',
    keyHint: 'sk-...',
    description: 'DeepSeek 官方 API，中文训练分析表现稳定。',
    models: [
      AiModelPreset('deepseek-chat', 'DeepSeek Chat'),
      AiModelPreset('deepseek-reasoner', 'DeepSeek Reasoner'),
    ],
  ),
  AiProviderPreset(
    id: 'zhipu',
    label: '智谱 GLM',
    endpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    keyHint: 'API Key',
    description: '智谱开放平台，含免费 GLM-4V-Flash 视觉模型。',
    models: [
      AiModelPreset('glm-4.5-flash', 'GLM-4.5-Flash（免费）', free: true),
      AiModelPreset('glm-4v-flash', 'GLM-4V-Flash（免费 · 视觉）',
          supportsVision: true, free: true),
      AiModelPreset('glm-4.5', 'GLM-4.5'),
      AiModelPreset('glm-4.5v', 'GLM-4.5V', supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'qwen',
    label: '阿里云百炼 Qwen',
    endpoint:
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    keyHint: 'sk-...',
    description: '通义千问 OpenAI 兼容接口，视觉模型丰富。',
    models: [
      AiModelPreset('qwen-flash', 'Qwen Flash'),
      AiModelPreset('qwen-plus', 'Qwen Plus'),
      AiModelPreset('qwen3-max', 'Qwen3 Max'),
      AiModelPreset('qwen-vl-plus', 'Qwen VL Plus（视觉）', supportsVision: true),
      AiModelPreset('qwen-vl-max', 'Qwen VL Max（视觉）', supportsVision: true),
      AiModelPreset('qwen3-vl-plus', 'Qwen3 VL Plus（视觉）', supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'moonshot',
    label: 'Moonshot Kimi',
    endpoint: 'https://api.moonshot.cn/v1/chat/completions',
    keyHint: 'sk-...',
    description: 'Kimi 官方 API，长上下文、中文表达自然。',
    models: [
      AiModelPreset('kimi-k2.5', 'Kimi K2.5'),
      AiModelPreset('kimi-k2-turbo-preview', 'Kimi K2 Turbo'),
      AiModelPreset('moonshot-v1-8k-vision-preview', 'Moonshot Vision',
          supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'minimax',
    label: 'MiniMax',
    endpoint: 'https://api.minimaxi.com/v1/chat/completions',
    keyHint: 'API Key',
    description: 'MiniMax 官方 OpenAI 兼容接口。',
    models: [
      AiModelPreset('MiniMax-M2.5', 'MiniMax M2.5'),
      AiModelPreset('MiniMax-M2.1', 'MiniMax M2.1'),
      AiModelPreset('abab6.5s-chat', 'abab6.5s'),
    ],
  ),
  AiProviderPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    endpoint: 'https://openrouter.ai/api/v1/chat/completions',
    keyHint: 'sk-or-...',
    description: '聚合多家模型，一个 Key 可用全部主流模型。',
    models: [
      AiModelPreset('google/gemini-3-flash', 'Gemini 3 Flash',
          supportsVision: true),
      AiModelPreset('google/gemini-2.5-flash', 'Gemini 2.5 Flash',
          supportsVision: true),
      AiModelPreset('anthropic/claude-sonnet-4.5', 'Claude Sonnet 4.5',
          supportsVision: true),
      AiModelPreset('openai/gpt-5-mini', 'GPT-5 Mini', supportsVision: true),
      AiModelPreset('deepseek/deepseek-chat', 'DeepSeek Chat'),
      AiModelPreset('qwen/qwen3-vl-235b-a22b-instruct', 'Qwen3 VL 235B',
          supportsVision: true),
      AiModelPreset('meta-llama/llama-4-maverick', 'Llama 4 Maverick',
          supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'groq',
    label: 'Groq',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
    keyHint: 'gsk_...',
    description: 'Groq 高速推理，适合快速问答。',
    models: [
      AiModelPreset('llama-3.3-70b-versatile', 'Llama 3.3 70B'),
      AiModelPreset('llama-4-maverick-17b-128e-instruct', 'Llama 4 Maverick',
          supportsVision: true),
      AiModelPreset('qwen/qwen3-32b', 'Qwen3 32B'),
      AiModelPreset('moonshotai/kimi-k2-instruct', 'Kimi K2'),
    ],
  ),
  AiProviderPreset(
    id: 'mistral',
    label: 'Mistral',
    endpoint: 'https://api.mistral.ai/v1/chat/completions',
    keyHint: 'API Key',
    description: 'Mistral 官方 API，Pixtral 支持图片识别。',
    models: [
      AiModelPreset('mistral-large-latest', 'Mistral Large'),
      AiModelPreset('mistral-small-latest', 'Mistral Small'),
      AiModelPreset('pixtral-large-latest', 'Pixtral Large（视觉）',
          supportsVision: true),
      AiModelPreset('pixtral-12b-2409', 'Pixtral 12B（视觉）',
          supportsVision: true),
    ],
  ),
  AiProviderPreset(
    id: 'siliconflow',
    label: '硅基流动 SiliconFlow',
    endpoint: 'https://api.siliconflow.cn/v1/chat/completions',
    keyHint: 'sk-...',
    description: '国内聚合服务，含多种视觉模型。',
    models: [
      AiModelPreset('deepseek-ai/DeepSeek-V3.2', 'DeepSeek V3.2'),
      AiModelPreset('Qwen/Qwen3-32B', 'Qwen3 32B'),
      AiModelPreset('Qwen/Qwen3-VL-32B-Instruct', 'Qwen3 VL 32B（视觉）',
          supportsVision: true),
      AiModelPreset('THUDM/GLM-4.1V-9B-Thinking', 'GLM-4.1V（视觉）',
          supportsVision: true),
    ],
  ),
  customAiProvider,
];

AiProviderPreset aiProviderById(String id) {
  return builtInAiProviders.firstWhere(
    (provider) => provider.id == id,
    orElse: () => customAiProvider,
  );
}

AiProviderPreset? aiProviderForEndpoint(String endpoint) {
  final normalized = endpoint.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final provider in builtInAiProviders) {
    if (provider.endpoint.isNotEmpty &&
        provider.endpoint.toLowerCase() == normalized) {
      return provider;
    }
  }
  if (normalized.contains('blockrun')) return aiProviderById('blockrun');
  if (normalized.contains('pollinations')) {
    return aiProviderById('pollinations');
  }
  if (normalized.contains('opencode')) return aiProviderById('opencode');
  if (normalized.contains('openai.com')) return aiProviderById('openai');
  if (normalized.contains('anthropic')) return aiProviderById('anthropic');
  if (normalized.contains('googleapis')) return aiProviderById('google');
  if (normalized.contains('deepseek')) return aiProviderById('deepseek');
  if (normalized.contains('bigmodel')) return aiProviderById('zhipu');
  if (normalized.contains('dashscope')) return aiProviderById('qwen');
  if (normalized.contains('moonshot')) return aiProviderById('moonshot');
  if (normalized.contains('minimax')) return aiProviderById('minimax');
  if (normalized.contains('openrouter')) return aiProviderById('openrouter');
  if (normalized.contains('groq')) return aiProviderById('groq');
  if (normalized.contains('mistral')) return aiProviderById('mistral');
  if (normalized.contains('siliconflow')) return aiProviderById('siliconflow');
  return null;
}

AiModelPreset? aiModelPreset(String endpoint, String model) {
  final provider = aiProviderForEndpoint(endpoint);
  if (provider == null) return null;
  for (final preset in provider.models) {
    if (preset.id == model) return preset;
  }
  return null;
}

bool aiModelSupportsVision(String endpoint, String model) {
  return aiModelPreset(endpoint, model)?.supportsVision ?? false;
}

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeProvider(
    String initialThemeId, {
    AppThemeMode initialMode = AppThemeMode.light,
  })  : _themeId = AppThemes.byId(initialThemeId).id,
        _mode = initialMode,
        _platformBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness {
    WidgetsBinding.instance.addObserver(this);
    _loadCustomBackground();
  }

  String _themeId;
  AppThemeMode _mode;
  Brightness _platformBrightness;
  String? _customBackgroundPath;

  String get themeId => _themeId;
  AppThemeMode get mode => _mode;
  AppThemeSpec get currentSpec => specFor(_themeId);
  AppThemeSpec specFor(String id) => AppThemes.byId(id).specFor(
        mode: _mode,
        platformBrightness: _platformBrightness,
      );
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
    AppHaptics.select();
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    AppHaptics.select();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeId = prefs.getString('selected_theme_id');
    _themeId = AppThemes.byId(savedThemeId ?? _themeId).id;
    final savedMode = prefs.getString('theme_mode');
    if (savedMode != null) {
      _mode = AppThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => _mode,
      );
    }
    _customBackgroundPath = prefs.getString('theme_custom_background');
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next == _platformBrightness) return;
    _platformBrightness = next;
    if (_mode == AppThemeMode.system) notifyListeners();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class SettingsProvider extends ChangeNotifier {
  static const String defaultAiProviderId = 'blockrun';
  static const String defaultAiEndpoint =
      'https://blockrun.ai/api/v1/chat/completions';
  static const String defaultAiModel = 'nvidia/gpt-oss-20b';
  static const String legacyAiEndpoint =
      'https://opencode.ai/inference/openai/v1/chat/completions';
  static const String legacyAiModel = 'big-pickle';
  static const String legacyPollinationsEndpoint =
      'https://text.pollinations.ai/openai';

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
    '🏃',
    '🧗',
    '🚴',
    '🏊',
    '🥊',
    '⛹️',
    '🎾',
    '⚽',
    '🏀',
    '🥩',
    '🥦',
    '🍗',
    '💤',
    '⏰',
    '📈',
    '🧠',
    '❤️',
    '🐺',
    '🦁',
    '🐯',
    '🦅',
    '⚔️',
    '🛡️',
    '👑',
    '💎',
    '🌊',
    '🗻',
    '🎸',
    '🎮',
    '📚',
    '🎓',
    '🧭',
    '🔨',
    '🪓',
    '⚙️',
    '🧲',
  ];

  String _nickname = '铁友';
  String _trainingGoal = '增肌';
  String _experience = '进阶';
  double _bodyWeight = 70;
  double? _heightCm;
  int? _age;
  String _sex = '未填写';
  double? _bodyFatPercent;
  int? _restingHeartRate;
  double? _trainingYears;
  DateTime _streakStart = DateTime(2025, 6, 9, 18, 29);
  int _weeklyGoal = 4;
  String _weightUnit = 'kg';
  int _restSeconds = 90;
  bool _haptics = false;
  bool _hapticsVibration = false;
  bool _hapticsMotion = false;
  bool _remindersEnabled = false;
  String _reminderTime = '20:00';
  String _reminderMessage = 'Hey！撸铁时间到';
  bool _dashboardCameraEnabled = false;
  bool _dashboardAiScanEnabled = false;

  bool _aiEnabled = false;
  String _aiProviderId = defaultAiProviderId;
  String _aiEndpoint = defaultAiEndpoint;
  String _aiModel = defaultAiModel;
  String _aiApiKey = '';
  String _aiPrompt = '';
  final Map<String, String> _aiProviderKeys = {};

  String _statusEmoji = '🔥';
  String _statusText = '今天的铁，也要镌刻进身体里';
  String? _statusImagePath;
  int _statusTone = 0;
  int _statusMotion = 0;
  int _statusBattery = 80;
  String? _avatarPath;

  String get nickname => _nickname;
  String get trainingGoal => _trainingGoal;
  String get experience => _experience;
  double get bodyWeight => _bodyWeight;
  double? get heightCm => _heightCm;
  int? get age => _age;
  String get sex => _sex;
  double? get bodyFatPercent => _bodyFatPercent;
  int? get restingHeartRate => _restingHeartRate;
  double? get trainingYears => _trainingYears;
  DateTime get streakStart => _streakStart;
  bool get hasStreakStart => _streakStart.isAfter(DateTime(2020, 1, 1));
  IronProfile get ironProfile => IronProfile.instance;
  int get weeklyGoal => _weeklyGoal;
  String get weightUnit => _weightUnit;
  int get restSeconds => _restSeconds;
  bool get haptics => _haptics;
  bool get hapticsVibration => _hapticsVibration;
  bool get hapticsMotion => _hapticsMotion;
  bool get remindersEnabled => _remindersEnabled;
  String get reminderTime => _reminderTime;
  String get reminderMessage => _reminderMessage;
  bool get dashboardCameraEnabled => _dashboardCameraEnabled;
  bool get dashboardAiScanEnabled => _dashboardAiScanEnabled;

  bool get aiEnabled => _aiEnabled;
  String get aiProviderId => _aiProviderId;
  AiProviderPreset get aiProvider => aiProviderById(_aiProviderId);
  String get aiEndpoint => _aiEndpoint;
  String get aiModel => _aiModel;
  String get aiApiKey => _aiApiKey;
  String get aiPrompt => _aiPrompt;
  bool get hasAiKey => _aiApiKey.trim().isNotEmpty;

  String apiKeyForProvider(String providerId) {
    if (providerId == _aiProviderId) return _aiApiKey;
    return _aiProviderKeys[providerId] ?? '';
  }

  String get statusEmoji => _statusEmoji;
  String get statusText => _statusText;
  String? get statusImagePath => _statusImagePath;
  int get statusTone => _statusTone;
  int get statusMotion => _statusMotion;
  int get statusBattery => _statusBattery;
  String? get avatarPath => _avatarPath;
  bool get hasAvatar => _avatarPath != null && _avatarPath!.trim().isNotEmpty;

  String get todayQuote {
    final index =
        DateTime.now().difference(DateTime(2020)).inDays % quotes.length;
    return quotes[index.abs() % quotes.length];
  }

  late final Future<void> ready;

  SettingsProvider() {
    ready = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString('profile_nickname') ?? '铁友';
    _trainingGoal = prefs.getString('profile_goal') ?? '增肌';
    _experience = prefs.getString('profile_experience') ?? '进阶';
    _bodyWeight = prefs.getDouble('profile_body_weight') ?? 70;
    _heightCm = prefs.getDouble('profile_height_cm');
    _age = prefs.getInt('profile_age');
    _sex = prefs.getString('profile_sex') ?? '未填写';
    _bodyFatPercent = prefs.getDouble('profile_body_fat');
    _restingHeartRate = prefs.getInt('profile_resting_hr');
    _trainingYears = prefs.getDouble('profile_training_years');
    final savedStreakStart = prefs.getString('first_workout_date');
    if (savedStreakStart != null) {
      _streakStart = DateTime.tryParse(savedStreakStart) ?? _streakStart;
    }
    _weeklyGoal = prefs.getInt('training_weekly_goal') ?? 4;
    _weightUnit = prefs.getString('training_weight_unit') ?? 'kg';
    _restSeconds = prefs.getInt('training_rest_seconds') ?? 90;
    _haptics = prefs.getBool('training_haptics') ?? false;
    _hapticsVibration = prefs.getBool('training_haptics_vibration') ?? _haptics;
    _hapticsMotion = prefs.getBool('training_haptics_motion') ?? _haptics;
    _syncHaptics();
    _remindersEnabled = prefs.getBool('reminder_enabled') ?? false;
    _reminderTime = prefs.getString('reminder_time') ?? '20:00';
    _reminderMessage = prefs.getString('reminder_message') ?? 'Hey！撸铁时间到';
    _dashboardCameraEnabled =
        prefs.getBool('dashboard_camera_enabled') ?? false;
    _dashboardAiScanEnabled =
        prefs.getBool('dashboard_ai_scan_enabled') ?? false;

    _aiEnabled = prefs.getBool('ai_enabled') ?? false;
    var savedEndpoint = prefs.getString('ai_endpoint');
    var savedModel = prefs.getString('ai_model');
    final defaultsVersion = prefs.getInt('ai_defaults_version') ?? 0;
    if (defaultsVersion < 4) {
      final endpointMigrated = savedEndpoint == null ||
          savedEndpoint == legacyAiEndpoint ||
          savedEndpoint == legacyPollinationsEndpoint;
      if (endpointMigrated) {
        savedEndpoint = defaultAiEndpoint;
        await prefs.setString('ai_endpoint', savedEndpoint);
      }
      if (endpointMigrated ||
          savedModel == null ||
          savedModel == legacyAiModel ||
          savedModel == 'openai' ||
          savedModel == 'gpt-oss-20b') {
        savedModel = defaultAiModel;
        await prefs.setString('ai_model', savedModel);
      }
      await prefs.setInt('ai_defaults_version', 4);
    }
    _aiEndpoint = savedEndpoint ?? defaultAiEndpoint;
    _aiModel = savedModel ?? defaultAiModel;
    final savedProviderId = prefs.getString('ai_provider_id');
    _aiProviderId = savedProviderId ??
        aiProviderForEndpoint(_aiEndpoint)?.id ??
        defaultAiProviderId;
    for (final provider in builtInAiProviders) {
      final value = prefs.getString('ai_api_key_${provider.id}');
      if (value != null) _aiProviderKeys[provider.id] = value;
    }
    final legacyKey = prefs.getString('ai_api_key') ?? '';
    _aiApiKey = _aiProviderKeys[_aiProviderId] ?? legacyKey;
    if (_aiApiKey.isNotEmpty) {
      _aiProviderKeys[_aiProviderId] = _aiApiKey;
    }
    _aiPrompt = prefs.getString('ai_prompt') ?? '';

    _statusEmoji = prefs.getString('status_emoji') ?? '🔥';
    _statusText = prefs.getString('status_text') ?? '今天的铁，也要镌刻进身体里';
    _statusImagePath = prefs.getString('status_image_path');
    _statusTone = prefs.getInt('status_tone') ?? 0;
    _statusMotion = prefs.getInt('status_motion') ?? 0;
    _statusBattery = (prefs.getInt('status_battery') ?? 80).clamp(0, 100);
    _avatarPath = prefs.getString('profile_avatar_path');
    _syncIronProfile();
    notifyListeners();
  }

  void _syncIronProfile() {
    IronProfile.instance.update(
      bodyWeightKg: _bodyWeight,
      heightCm: _heightCm,
      age: _age,
      sex: switch (_sex) {
        '男' => IronSex.male,
        '女' => IronSex.female,
        _ => IronSex.unspecified,
      },
      bodyFatPercent: _bodyFatPercent,
      restingHeartRate: _restingHeartRate,
      trainingYears: _trainingYears,
      experience: _experience,
      goal: _trainingGoal,
      clearHeight: _heightCm == null,
      clearAge: _age == null,
      clearBodyFat: _bodyFatPercent == null,
      clearRestingHeartRate: _restingHeartRate == null,
      clearTrainingYears: _trainingYears == null,
    );
  }

  void _syncHaptics() {
    AppHaptics.enabled = _haptics;
    AppHaptics.vibrationEnabled = _hapticsVibration;
    AppHaptics.motionEnabled = _hapticsMotion;
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

  Future<void> reload() => _load();

  Future<void> setNickname(String value) async {
    _nickname = value.trim().isEmpty ? '铁友' : value.trim();
    await _persist('profile_nickname', _nickname);
    notifyListeners();
  }

  Future<void> setTrainingGoal(String value) async {
    _trainingGoal = value;
    await _persist('profile_goal', value);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setExperience(String value) async {
    _experience = value;
    await _persist('profile_experience', value);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setBodyWeight(double value) async {
    _bodyWeight = value.clamp(20, 350);
    await _persist('profile_body_weight', _bodyWeight);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setHeightCm(double? value) async {
    _heightCm = value?.clamp(100, 250);
    await _persist('profile_height_cm', _heightCm);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setAge(int? value) async {
    _age = value?.clamp(10, 100);
    await _persist('profile_age', _age);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setSex(String value) async {
    _sex = ['男', '女'].contains(value) ? value : '未填写';
    await _persist('profile_sex', _sex);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setBodyFatPercent(double? value) async {
    _bodyFatPercent = value?.clamp(3, 60);
    await _persist('profile_body_fat', _bodyFatPercent);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setRestingHeartRate(int? value) async {
    _restingHeartRate = value?.clamp(30, 120);
    await _persist('profile_resting_hr', _restingHeartRate);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setTrainingYears(double? value) async {
    _trainingYears = value?.clamp(0, 60);
    await _persist('profile_training_years', _trainingYears);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setStreakStart(DateTime value) async {
    _streakStart = value;
    await _persist('first_workout_date', value.toIso8601String());
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
    if (value && !_hapticsVibration && !_hapticsMotion) {
      _hapticsVibration = true;
      _hapticsMotion = true;
    }
    _syncHaptics();
    notifyListeners();
    await _persist('training_haptics', value);
    if (value) {
      if (_hapticsVibration) {
        await _persist('training_haptics_vibration', true);
      }
      if (_hapticsMotion) {
        await _persist('training_haptics_motion', true);
      }
      AppHaptics.light();
    }
  }

  Future<void> setHapticsVibration(bool value) async {
    _hapticsVibration = value;
    _syncHaptics();
    if (value) AppHaptics.light();
    notifyListeners();
    await _persist('training_haptics_vibration', value);
  }

  Future<void> setHapticsMotion(bool value) async {
    _hapticsMotion = value;
    _syncHaptics();
    notifyListeners();
    await _persist('training_haptics_motion', value);
  }

  Future<void> setRemindersEnabled(bool value) async {
    _remindersEnabled = value;
    await _persist('reminder_enabled', value);
    notifyListeners();
  }

  Future<void> setDashboardCameraEnabled(bool value) async {
    _dashboardCameraEnabled = value;
    await _persist('dashboard_camera_enabled', value);
    notifyListeners();
  }

  Future<void> setDashboardAiScanEnabled(bool value) async {
    _dashboardAiScanEnabled = value;
    await _persist('dashboard_ai_scan_enabled', value);
    notifyListeners();
  }

  Future<void> setReminderTime(String value) async {
    _reminderTime = value;
    await _persist('reminder_time', value);
    notifyListeners();
  }

  Future<void> setReminderMessage(String value) async {
    _reminderMessage = value;
    await _persist('reminder_message', value);
    notifyListeners();
  }

  Future<void> setAiEnabled(bool value) async {
    _aiEnabled = value;
    await _persist('ai_enabled', value);
    notifyListeners();
  }

  Future<void> setAiConfig({
    String? providerId,
    String? endpoint,
    String? model,
    String? apiKey,
  }) async {
    if (providerId != null && providerId.trim().isNotEmpty) {
      _aiProviderId = providerId.trim();
      await _persist('ai_provider_id', _aiProviderId);
    }
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
      _aiProviderKeys[_aiProviderId] = _aiApiKey;
      await _persist('ai_api_key_$_aiProviderId', _aiApiKey);
      await _persist('ai_api_key', _aiApiKey);
    } else {
      _aiApiKey = _aiProviderKeys[_aiProviderId] ?? '';
    }
    notifyListeners();
  }

  Future<void> setAiPrompt(String value) async {
    _aiPrompt = value.trim();
    await _persist('ai_prompt', _aiPrompt);
    notifyListeners();
  }

  Future<void> setStatus({
    String? emoji,
    String? text,
    String? imagePath,
    bool clearImage = false,
    int? tone,
    int? motion,
    int? battery,
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
    if (battery != null) {
      _statusBattery = battery.clamp(0, 100);
      await _persist('status_battery', _statusBattery);
    }
    notifyListeners();
  }

  Future<void> setStatusBattery(int value) async {
    _statusBattery = value.clamp(0, 100);
    await _persist('status_battery', _statusBattery);
    notifyListeners();
  }

  Future<void> setAvatarPath(String path) async {
    _avatarPath = path.trim().isEmpty ? null : path.trim();
    await _persist('profile_avatar_path', _avatarPath);
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    _avatarPath = null;
    await _persist('profile_avatar_path', null);
    notifyListeners();
  }
}
