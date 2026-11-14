import 'dart:io';

import 'package:fitness_tracker/services/ai_coach_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chatStream separates reasoning and answer chunks', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      final response = request.response;
      response.statusCode = HttpStatus.ok;
      response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      response.write(
        'data: {"choices":[{"delta":{"reasoning_content":"先思考"}}]}\n\n',
      );
      response.write('data: {"choices":[{"delta":{"content":"最终回答"}}]}\n\n');
      response.write('data: [DONE]\n\n');
      await response.close();
    });

    final events = <String>[];
    var reasoningDone = false;
    final reply = await AiCoachService.chatStream(
      endpoint: 'http://127.0.0.1:${server.port}/',
      model: 'test-model',
      messages: const [
        {'role': 'user', 'content': '你好'},
      ],
      onReasoningChunk: (delta) => events.add('reasoning:$delta'),
      onContentChunk: (delta) => events.add('content:$delta'),
      onReasoningDone: () => reasoningDone = true,
    );

    expect(reply.success, isTrue);
    expect(reply.reasoning, '先思考');
    expect(reply.content, '最终回答');
    expect(
      events,
      ['reasoning:先思考', 'content:最终回答'],
    );
    expect(reasoningDone, isTrue);

    await server.close(force: true);
  });
}
