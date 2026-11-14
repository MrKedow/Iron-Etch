import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../providers/app_providers.dart';

class AiCoachReply {
  final bool success;
  final String content;
  final String reasoning;
  final String? error;
  final int? statusCode;
  final String? channel;

  const AiCoachReply({
    required this.success,
    required this.content,
    this.reasoning = '',
    this.error,
    this.statusCode,
    this.channel,
  });

  factory AiCoachReply.failure(String message, {int? statusCode}) {
    return AiCoachReply(
      success: false,
      content: '',
      error: message,
      statusCode: statusCode,
    );
  }
}

class _AiTarget {
  final String endpoint;
  final String model;
  final String label;
  final String? apiKey;
  final String? reasoningEffort;

  const _AiTarget({
    required this.endpoint,
    required this.model,
    required this.label,
    this.apiKey,
    this.reasoningEffort,
  });
}

class _AiExtractedReply {
  final String content;
  final String reasoning;

  const _AiExtractedReply({
    required this.content,
    required this.reasoning,
  });
}

class _AiThinkingSplit {
  final String content;
  final String reasoning;

  const _AiThinkingSplit({
    required this.content,
    required this.reasoning,
  });
}

class AiCoachService {
  static const String pollinationsEndpoint =
      'https://text.pollinations.ai/openai';
  static const String pollinationsCompatEndpoint =
      'https://text.pollinations.ai/openai/chat/completions';
  static const String pollinationsV1Endpoint =
      'https://text.pollinations.ai/openai/v1/chat/completions';
  static const String blockRunEndpoint =
      'https://blockrun.ai/api/v1/chat/completions';
  static const String openCodeEndpoint =
      'https://opencode.ai/inference/openai/v1/chat/completions';

  static Future<AiCoachReply> chat({
    required List<Map<String, dynamic>> messages,
    String? endpoint,
    String? model,
    String? apiKey,
    String? reasoningEffort,
  }) async {
    final configured = (endpoint == null || endpoint.trim().isEmpty)
        ? SettingsProvider.defaultAiEndpoint
        : endpoint.trim();
    final primaryUri = Uri.tryParse(configured);
    if (primaryUri == null || !primaryUri.hasScheme) {
      return AiCoachReply.failure('AI 接口地址无效，请在设置中检查。');
    }

    final key = apiKey?.trim() ?? '';
    final configuredModel = (model == null || model.trim().isEmpty)
        ? SettingsProvider.defaultAiModel
        : model.trim();
    final targets = _chatTargets(
      endpoint: configured,
      model: configuredModel,
      apiKey: key,
      reasoningEffort: reasoningEffort,
    );

    final errors = <String>[];
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final reply = await _attempt(
        target,
        messages,
        apiKey: key,
        timeout: Duration(seconds: i == 0 ? 35 : 25),
      );
      if (reply.success) return reply;
      errors.add('${target.label}：${reply.error ?? '未知错误'}');

      // 自定义 Key 只发送给用户配置的主通道，绝不外泄到公共回退通道。
      if (key.isNotEmpty) break;
    }

    if (errors.length > 1) {
      return AiCoachReply.failure('所有 AI 通道均不可用。${errors.join('；')}');
    }
    return AiCoachReply.failure(errors.isEmpty ? 'AI 服务不可用。' : errors.first);
  }

  static Future<AiCoachReply> chatStream({
    required List<Map<String, dynamic>> messages,
    String? endpoint,
    String? model,
    String? apiKey,
    String? reasoningEffort,
    void Function(String delta)? onReasoningChunk,
    void Function(String delta)? onContentChunk,
    void Function()? onReasoningDone,
  }) async {
    final configured = (endpoint == null || endpoint.trim().isEmpty)
        ? SettingsProvider.defaultAiEndpoint
        : endpoint.trim();
    final primaryUri = Uri.tryParse(configured);
    if (primaryUri == null || !primaryUri.hasScheme) {
      return AiCoachReply.failure('AI 接口地址无效，请在设置中检查。');
    }

    final key = apiKey?.trim() ?? '';
    final configuredModel = (model == null || model.trim().isEmpty)
        ? SettingsProvider.defaultAiModel
        : model.trim();
    final targets = _chatTargets(
      endpoint: configured,
      model: configuredModel,
      apiKey: key,
      reasoningEffort: reasoningEffort,
    );
    final errors = <String>[];
    var emitted = false;
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final allowCallbacks = !emitted;
      final reply = await _attemptStream(
        target,
        messages,
        apiKey: key,
        timeout: Duration(seconds: i == 0 ? 45 : 30),
        onReasoningChunk: allowCallbacks
            ? (delta) {
                emitted = true;
                onReasoningChunk?.call(delta);
              }
            : null,
        onContentChunk: allowCallbacks
            ? (delta) {
                emitted = true;
                onContentChunk?.call(delta);
              }
            : null,
        onReasoningDone: allowCallbacks ? onReasoningDone : null,
      );
      if (reply.success) return reply;
      errors.add('${target.label}：${reply.error ?? '未知错误'}');
      if (key.isNotEmpty) break;
    }
    if (errors.length > 1) {
      return AiCoachReply.failure('所有 AI 通道均不可用。${errors.join('；')}');
    }
    return AiCoachReply.failure(errors.isEmpty ? 'AI 服务不可用。' : errors.first);
  }

  static List<_AiTarget> _chatTargets({
    required String endpoint,
    required String model,
    required String apiKey,
    String? reasoningEffort,
  }) {
    final targets = <_AiTarget>[
      _AiTarget(
        endpoint: endpoint,
        model: model,
        label: _labelFor(endpoint),
        reasoningEffort: reasoningEffort,
      ),
    ];
    if (apiKey.isNotEmpty) return targets;
    for (final fallback in const [
      _AiTarget(
        endpoint: blockRunEndpoint,
        model: 'nvidia/gpt-oss-20b',
        label: 'BlockRun',
      ),
      _AiTarget(
        endpoint: pollinationsEndpoint,
        model: 'gpt-oss-20b',
        label: 'Pollinations',
      ),
      _AiTarget(
        endpoint: pollinationsCompatEndpoint,
        model: 'gpt-oss-20b',
        label: 'Pollinations',
      ),
      _AiTarget(
        endpoint: pollinationsV1Endpoint,
        model: 'gpt-oss-20b',
        label: 'Pollinations',
      ),
      _AiTarget(
        endpoint: openCodeEndpoint,
        model: 'big-pickle',
        label: 'OpenCode Zen',
      ),
    ]) {
      if (targets.any((target) => target.endpoint == fallback.endpoint)) {
        continue;
      }
      targets.add(fallback);
    }
    return targets;
  }

  static Future<AiCoachReply> testConnection({
    String? endpoint,
    String? model,
    String? apiKey,
    String? reasoningEffort,
  }) {
    return chat(
      endpoint: endpoint,
      model: model,
      apiKey: apiKey,
      reasoningEffort: reasoningEffort,
      messages: [
        {
          'role': 'system',
          'content': '你是铁镌健身应用的健康助手。只回复一句不超过20字的中文问候。',
        },
        {
          'role': 'user',
          'content': '请回复：连接成功。',
        },
      ],
    );
  }

  /// 读取跑步机/椭圆机仪表盘照片，返回包含时长、距离、速度和热量的文本。
  /// 优先使用用户配置的视觉模型，否则自动回退到快速免费的视觉模型。
  static Future<AiCoachReply> readCardioDashboard({
    required String imageBase64,
    String mimeType = 'image/jpeg',
    String? endpoint,
    String? model,
    String? apiKey,
  }) async {
    final configuredEndpoint = (endpoint == null || endpoint.trim().isEmpty)
        ? SettingsProvider.defaultAiEndpoint
        : endpoint.trim();
    final configuredModel = (model == null || model.trim().isEmpty)
        ? SettingsProvider.defaultAiModel
        : model.trim();
    final key = apiKey?.trim() ?? '';
    final provider = aiProviderForEndpoint(configuredEndpoint);
    final targets = <_AiTarget>[];
    final configuredVision =
        aiModelSupportsVision(configuredEndpoint, configuredModel) ||
            _looksLikeVisionModel(configuredModel);

    void addTarget(_AiTarget target) {
      final exists = targets.any(
        (item) =>
            item.endpoint == target.endpoint && item.model == target.model,
      );
      if (!exists) targets.add(target);
    }

    if (configuredVision) {
      addTarget(_AiTarget(
        endpoint: configuredEndpoint,
        model: configuredModel,
        label: '已配置视觉模型',
        apiKey: key,
      ));
    }

    if (key.isNotEmpty && provider != null) {
      final fallback = _providerVisionTarget(provider.id, key);
      if (fallback != null) addTarget(fallback);
    }

    addTarget(_AiTarget(
      endpoint: openCodeEndpoint,
      model: 'nemotron-3.5-super-vl-free',
      label: 'OpenCode Zen · 免费视觉',
      apiKey: provider?.id == 'opencode' ? key : '',
    ));

    final messages = _visionMessages(imageBase64, mimeType);
    final errors = <String>[];
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final reply = await _attempt(
        target,
        messages,
        apiKey: target.apiKey ?? '',
        timeout: Duration(seconds: i == 0 ? 22 : 18),
        temperature: .1,
        maxTokens: 500,
      );
      if (reply.success) return reply;
      errors.add('${target.label}：${reply.error ?? '未知错误'}');
    }
    return AiCoachReply.failure(
      errors.isEmpty ? '没有可用的视觉模型。' : errors.join('；'),
    );
  }

  static _AiTarget? _providerVisionTarget(String providerId, String key) {
    switch (providerId) {
      case 'openai':
        return _AiTarget(
          endpoint: 'https://api.openai.com/v1/chat/completions',
          model: 'gpt-5.4-mini',
          label: 'OpenAI 视觉',
          apiKey: key,
        );
      case 'anthropic':
        return _AiTarget(
          endpoint: 'https://api.anthropic.com/v1/chat/completions',
          model: 'claude-sonnet-4-5',
          label: 'Claude 视觉',
          apiKey: key,
        );
      case 'google':
        return _AiTarget(
          endpoint:
              'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
          model: 'gemini-3.5-flash',
          label: 'Gemini 视觉',
          apiKey: key,
        );
      case 'zhipu':
        return _AiTarget(
          endpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
          model: 'glm-4v-flash',
          label: 'GLM 视觉',
          apiKey: key,
        );
      case 'qwen':
        return _AiTarget(
          endpoint:
              'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          model: 'qwen-vl-plus',
          label: 'Qwen 视觉',
          apiKey: key,
        );
      case 'openrouter':
        return _AiTarget(
          endpoint: 'https://openrouter.ai/api/v1/chat/completions',
          model: 'google/gemini-3-flash',
          label: 'OpenRouter 视觉',
          apiKey: key,
        );
      case 'siliconflow':
        return _AiTarget(
          endpoint: 'https://api.siliconflow.cn/v1/chat/completions',
          model: 'Qwen/Qwen3-VL-32B-Instruct',
          label: 'SiliconFlow 视觉',
          apiKey: key,
        );
      case 'mistral':
        return _AiTarget(
          endpoint: 'https://api.mistral.ai/v1/chat/completions',
          model: 'pixtral-large-latest',
          label: 'Pixtral 视觉',
          apiKey: key,
        );
      case 'groq':
        return _AiTarget(
          endpoint: 'https://api.groq.com/openai/v1/chat/completions',
          model: 'llama-4-maverick-17b-128e-instruct',
          label: 'Groq 视觉',
          apiKey: key,
        );
      case 'moonshot':
        return _AiTarget(
          endpoint: 'https://api.moonshot.cn/v1/chat/completions',
          model: 'moonshot-v1-8k-vision-preview',
          label: 'Kimi 视觉',
          apiKey: key,
        );
      default:
        return null;
    }
  }

  static List<Map<String, dynamic>> _visionMessages(
    String imageBase64,
    String mimeType,
  ) {
    return [
      {
        'role': 'system',
        'content': '你是健身器械仪表盘识别助手。只输出一个 JSON 对象，不要解释、不要 markdown。',
      },
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text': '读取图片中跑步机/椭圆机仪表盘的主数值，只输出 JSON：'
                '{"durationMinutes":数字,"distanceKm":数字,"speedKmH":数字,"calories":数字}。'
                '如果时长是 mm:ss 或 hh:mm:ss，请换算成分钟。'
                '距离单位若是米请换算成公里。无法识别的字段填 0，不要臆造。',
          },
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:$mimeType;base64,$imageBase64',
            },
          },
        ],
      },
    ];
  }

  static bool _looksLikeVisionModel(String model) {
    final lower = model.toLowerCase();
    return lower.contains('vl') ||
        lower.contains('vision') ||
        lower.contains('pixtral') ||
        lower.contains('gpt-4o') ||
        lower.contains('gpt-5') ||
        lower.contains('gemini') ||
        lower.contains('claude');
  }

  static Future<AiCoachReply> _attempt(
    _AiTarget target,
    List<Map<String, dynamic>> messages, {
    required String apiKey,
    required Duration timeout,
    double temperature = .65,
    int maxTokens = 8192,
  }) async {
    final uri = Uri.tryParse(target.endpoint);
    if (uri == null || !uri.hasScheme) {
      return AiCoachReply.failure('接口地址无效');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final effectiveKey = (target.apiKey == null || target.apiKey!.isEmpty)
        ? apiKey
        : target.apiKey!;
    if (effectiveKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveKey';
    }

    final reasoningPayload = aiReasoningPayload(
      target.endpoint,
      target.model,
      target.reasoningEffort,
    );
    final thinking = reasoningPayload['thinking'];
    final thinkingBudget = thinking is Map
        ? int.tryParse('${thinking['budget_tokens'] ?? ''}')
        : null;
    final effectiveMaxTokens =
        thinkingBudget != null && thinkingBudget >= maxTokens
            ? thinkingBudget + 2048
            : maxTokens;

    final body = jsonEncode({
      'model': target.model,
      'messages': messages,
      if (thinking == null) 'temperature': temperature,
      'max_tokens': effectiveMaxTokens,
      'stream': false,
      ...reasoningPayload,
    });

    final client = http.Client();
    try {
      final response =
          await client.post(uri, headers: headers, body: body).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final extracted = _extractReply(decoded);
        if (extracted.content.trim().isEmpty &&
            extracted.reasoning.trim().isEmpty) {
          return AiCoachReply.failure(
            '返回了空内容',
            statusCode: response.statusCode,
          );
        }
        return AiCoachReply(
          success: true,
          content: extracted.content,
          reasoning: extracted.reasoning,
          statusCode: response.statusCode,
          channel: target.label,
        );
      }

      final detail = _extractError(response.body);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return AiCoachReply.failure(
          effectiveKey.isEmpty ? '免费通道要求鉴权' : '鉴权失败，请检查 API Key',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 429) {
        return AiCoachReply.failure(
          '请求过多（429）',
          statusCode: response.statusCode,
        );
      }
      return AiCoachReply.failure(
        'HTTP ${response.statusCode}${detail.isEmpty ? '' : '：$detail'}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return AiCoachReply.failure('响应超时');
    } catch (e) {
      final text = _friendlyError(e);
      return AiCoachReply.failure(
        text.contains('网络') ? text : '无法连接：$text',
      );
    } finally {
      client.close();
    }
  }

  static Future<AiCoachReply> _attemptStream(
    _AiTarget target,
    List<Map<String, dynamic>> messages, {
    required String apiKey,
    required Duration timeout,
    double temperature = .65,
    int maxTokens = 8192,
    void Function(String delta)? onReasoningChunk,
    void Function(String delta)? onContentChunk,
    void Function()? onReasoningDone,
  }) async {
    final uri = Uri.tryParse(target.endpoint);
    if (uri == null || !uri.hasScheme) {
      return AiCoachReply.failure('接口地址无效');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream, application/json',
    };
    final effectiveKey = (target.apiKey == null || target.apiKey!.isEmpty)
        ? apiKey
        : target.apiKey!;
    if (effectiveKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveKey';
    }

    final reasoningPayload = aiReasoningPayload(
      target.endpoint,
      target.model,
      target.reasoningEffort,
    );
    final thinking = reasoningPayload['thinking'];
    final thinkingBudget = thinking is Map
        ? int.tryParse('${thinking['budget_tokens'] ?? ''}')
        : null;
    final effectiveMaxTokens =
        thinkingBudget != null && thinkingBudget >= maxTokens
            ? thinkingBudget + 2048
            : maxTokens;

    final body = jsonEncode({
      'model': target.model,
      'messages': messages,
      if (thinking == null) 'temperature': temperature,
      'max_tokens': effectiveMaxTokens,
      'stream': true,
      ...reasoningPayload,
    });

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = body;
      final response = await client.send(request).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(
          await response.stream.bytesToString().timeout(timeout),
        );
        if (response.statusCode == 401) {
          return AiCoachReply.failure(
            'Key 无效或无权限（401）',
            statusCode: response.statusCode,
          );
        }
        if (response.statusCode == 429) {
          return AiCoachReply.failure(
            '请求过多（429）',
            statusCode: response.statusCode,
          );
        }
        return AiCoachReply.failure(
          'HTTP ${response.statusCode}${detail.isEmpty ? '' : '：$detail'}',
          statusCode: response.statusCode,
        );
      }

      var reasoning = '';
      var content = '';
      var reasoningDone = false;

      void notifyReasoningDone() {
        if (reasoningDone) return;
        reasoningDone = true;
        onReasoningDone?.call();
      }

      void appendDelta(_AiExtractedReply delta) {
        if (delta.reasoning.isNotEmpty) {
          reasoning += delta.reasoning;
          onReasoningChunk?.call(delta.reasoning);
        }
        if (delta.content.isNotEmpty) {
          content += delta.content;
          onContentChunk?.call(delta.content);
        }
      }

      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/event-stream')) {
        final lines = response.stream
            .timeout(timeout)
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
          if (!trimmed.startsWith('data:')) continue;
          final data = trimmed.substring(5).trim();
          if (data == '[DONE]') break;
          dynamic decoded;
          try {
            decoded = jsonDecode(data);
          } catch (_) {
            continue;
          }
          if (decoded is Map && decoded['error'] != null) {
            return AiCoachReply.failure(
              _extractError(data),
              statusCode: response.statusCode,
            );
          }
          appendDelta(_extractDelta(decoded));
        }
        notifyReasoningDone();
      } else {
        final bodyText = await response.stream.bytesToString().timeout(timeout);
        final decoded = jsonDecode(bodyText);
        final extracted = _extractReply(decoded);
        reasoning = extracted.reasoning;
        content = extracted.content;
        if (reasoning.isNotEmpty) onReasoningChunk?.call(reasoning);
        if (content.isNotEmpty) onContentChunk?.call(content);
        notifyReasoningDone();
      }

      if (content.trim().isEmpty && reasoning.trim().isEmpty) {
        return AiCoachReply.failure(
          '返回了空内容',
          statusCode: response.statusCode,
        );
      }
      return AiCoachReply(
        success: true,
        content: _cleanContent(content),
        reasoning: reasoning.trim(),
        statusCode: response.statusCode,
        channel: target.label,
      );
    } on TimeoutException {
      return AiCoachReply.failure('响应超时');
    } catch (e) {
      final text = _friendlyError(e);
      return AiCoachReply.failure(
        text.contains('网络') ? text : '无法连接：$text',
      );
    } finally {
      client.close();
    }
  }

  static _AiExtractedReply _extractDelta(dynamic decoded) {
    if (decoded is! Map) {
      return const _AiExtractedReply(content: '', reasoning: '');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return const _AiExtractedReply(content: '', reasoning: '');
    }
    final choice = choices.first;
    if (choice is! Map) {
      return const _AiExtractedReply(content: '', reasoning: '');
    }
    final part = choice['delta'] ?? choice['message'];
    if (part is! Map) {
      return const _AiExtractedReply(content: '', reasoning: '');
    }
    return _AiExtractedReply(
      content: _firstText(part['content']),
      reasoning: _joinText([
        _firstText(part['reasoning_content']),
        _firstText(part['reasoning']),
        _firstText(part['thinking']),
        _reasoningDetails(part['reasoning_details']),
      ]),
    );
  }

  static String _labelFor(String endpoint) {
    final lower = endpoint.toLowerCase();
    if (lower.contains('blockrun')) return 'BlockRun';
    if (lower.contains('pollinations')) return 'Pollinations';
    if (lower.contains('opencode')) return 'OpenCode Zen';
    return '自定义 AI';
  }

  static _AiExtractedReply _extractReply(dynamic decoded) {
    var content = '';
    var reasoning = '';
    if (decoded is Map<String, dynamic>) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final contentValue = message['content'];
            if (contentValue is String) {
              content = contentValue;
            } else if (contentValue is List) {
              final contentParts = <String>[];
              final reasoningParts = <String>[];
              for (final part in contentValue) {
                if (part is! Map || part['text'] is! String) continue;
                final type = '${part['type'] ?? ''}'.toLowerCase();
                if (type.contains('reason') || type.contains('think')) {
                  reasoningParts.add(part['text'] as String);
                } else {
                  contentParts.add(part['text'] as String);
                }
              }
              content = contentParts.join();
              reasoning = reasoningParts.join();
            }
            reasoning = _joinText([
              reasoning,
              _firstText(message['reasoning_content']),
              _firstText(message['reasoning']),
              _firstText(message['thinking']),
              _reasoningDetails(message['reasoning_details']),
            ]);
          }
          if (content.trim().isEmpty) {
            content = _firstText(first['text']);
          }
        }
      }
      if (content.trim().isEmpty) {
        content = _firstText(decoded['output_text']);
      }
      if (reasoning.trim().isEmpty) {
        reasoning = _joinText([
          _firstText(decoded['reasoning_content']),
          _firstText(decoded['reasoning']),
        ]);
      }
    } else if (decoded is String) {
      content = decoded;
    }

    final split = _splitThinking(content);
    return _AiExtractedReply(
      content: split.content,
      reasoning: _joinText([reasoning, split.reasoning]),
    );
  }

  static String _firstText(dynamic value) {
    if (value is String) return value;
    if (value is List) {
      return value.map((item) {
        if (item is String) return item;
        if (item is Map) {
          return _firstText(item['text'] ?? item['content']);
        }
        return '';
      }).join();
    }
    if (value is Map) {
      return _firstText(value['text'] ?? value['content']);
    }
    return '';
  }

  static String _reasoningDetails(dynamic value) {
    if (value is! List) return '';
    return value.map((item) {
      if (item is Map) {
        return _firstText(item['text'] ?? item['summary'] ?? item['content']);
      }
      return _firstText(item);
    }).join('\n');
  }

  static String _joinText(List<String> parts) {
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('\n\n')
        .trim();
  }

  static _AiThinkingSplit _splitThinking(String input) {
    var content = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '  ');
    final reasoning = <String>[];
    content = content.replaceAllMapped(
      RegExp(
        r'<\s*(think(?:ing)?|reasoning)\b[^>]*>([\s\S]*?)<\s*/\s*\1\s*>',
        caseSensitive: false,
      ),
      (match) {
        reasoning.add(match.group(2) ?? '');
        return '';
      },
    );
    content = content.replaceAllMapped(
      RegExp(
        r'```(?:think|thinking|reasoning)\s*([\s\S]*?)```',
        caseSensitive: false,
      ),
      (match) {
        reasoning.add(match.group(1) ?? '');
        return '';
      },
    );
    var cleaned = _cleanContent(content);
    if (cleaned.isEmpty) {
      cleaned = '';
    }
    return _AiThinkingSplit(
      content: cleaned,
      reasoning: _joinText(reasoning),
    );
  }

  static String _cleanContent(String input) {
    var text = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '  ');
    text = text.replaceAll(RegExp(r'<\|[^>]*\|>'), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String _extractError(String body) {
    if (body.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return _short(error['message'].toString());
        }
        if (decoded['message'] != null) {
          return _short(decoded['message'].toString());
        }
      }
    } catch (_) {
      // ignore
    }
    return _short(body);
  }

  static String _short(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length > 120
        ? '${normalized.substring(0, 120)}…'
        : normalized;
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection')) {
      return '网络不可用或被拦截';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
