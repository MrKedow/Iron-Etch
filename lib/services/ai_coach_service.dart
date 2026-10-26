import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../providers/app_providers.dart';

class AiCoachReply {
  final bool success;
  final String content;
  final String? error;
  final int? statusCode;

  const AiCoachReply({
    required this.success,
    required this.content,
    this.error,
    this.statusCode,
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

class AiCoachService {
  static Future<AiCoachReply> chat({
    required List<Map<String, String>> messages,
    String? endpoint,
    String? model,
    String? apiKey,
  }) async {
    final uri = Uri.tryParse(
      (endpoint == null || endpoint.trim().isEmpty)
          ? SettingsProvider.defaultAiEndpoint
          : endpoint.trim(),
    );
    if (uri == null || !uri.hasScheme) {
      return AiCoachReply.failure('AI 接口地址无效，请在设置中检查。');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final key = apiKey?.trim() ?? '';
    if (key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    }

    final body = jsonEncode({
      'model': (model == null || model.trim().isEmpty)
          ? SettingsProvider.defaultAiModel
          : model.trim(),
      'messages': messages,
      'temperature': .65,
      'max_tokens': 1100,
      'stream': false,
    });

    try {
      final client = http.Client();
      final response = await client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 55));
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final content = _extractContent(decoded);
        if (content.trim().isEmpty) {
          return AiCoachReply.failure(
            'AI 返回了空内容，请稍后重试。',
            statusCode: response.statusCode,
          );
        }
        return AiCoachReply(
          success: true,
          content: content.trim(),
          statusCode: response.statusCode,
        );
      }

      final detail = _extractError(response.body);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return AiCoachReply.failure(
          'OpenCode 鉴权失败，请在设置中填入有效的 API Key。',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 429) {
        return AiCoachReply.failure(
          'OpenCode 免费通道正忙（429）。稍后再试，或在设置中配置 API Key。',
          statusCode: response.statusCode,
        );
      }
      return AiCoachReply.failure(
        'AI 请求失败（${response.statusCode}）${detail.isEmpty ? '' : '：$detail'}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return AiCoachReply.failure('AI 响应超时，请检查网络后重试。');
    } catch (e) {
      return AiCoachReply.failure('无法连接 AI 服务：${_friendlyError(e)}');
    }
  }

  static Future<AiCoachReply> testConnection({
    String? endpoint,
    String? model,
    String? apiKey,
  }) {
    return chat(
      endpoint: endpoint,
      model: model,
      apiKey: apiKey,
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

  static String _extractContent(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String) return content;
            if (content is List) {
              return content
                  .map((part) {
                    if (part is Map && part['text'] is String) {
                      return part['text'] as String;
                    }
                    return '';
                  })
                  .join();
            }
          }
          final text = first['text'];
          if (text is String) return text;
        }
      }
      final output = decoded['output_text'];
      if (output is String) return output;
    }
    if (decoded is String) return decoded;
    return '';
  }

  static String _extractError(String body) {
    if (body.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return error['message'].toString();
        }
        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
      }
    } catch (_) {
      // ignore
    }
    return body.length > 180 ? '${body.substring(0, 180)}…' : body;
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
