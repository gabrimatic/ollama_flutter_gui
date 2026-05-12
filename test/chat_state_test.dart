import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollama_flutter_gui/chat_state.dart';

void main() {
  late HttpServer server;
  final chatRequests = <Map<String, dynamic>>[];

  Future<void> startServer({
    Object? tagsBody,
    int tagsStatus = 200,
    Object? chatBody,
    int chatStatus = 200,
  }) async {
    chatRequests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;

      if (request.uri.path == '/api/tags') {
        request.response.statusCode = tagsStatus;
        request.response.write(jsonEncode(tagsBody ?? {'models': []}));
        await request.response.close();
        return;
      }

      if (request.uri.path == '/api/chat') {
        chatRequests.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.statusCode = chatStatus;
        request.response.write(jsonEncode(
          chatBody ??
              {
                'message': {'role': 'assistant', 'content': 'Pong'},
                'eval_count': 12,
                'eval_duration': 3000000000,
              },
        ));
        await request.response.close();
        return;
      }

      request.response.statusCode = 404;
      request.response.write(jsonEncode({'error': 'not found'}));
      await request.response.close();
    });
  }

  ProviderContainer buildContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('loads local models and selects the first discovered model', () async {
    await startServer(
      tagsBody: {
        'models': [
          {'name': 'zeta:latest', 'size': 2},
          {'name': 'gemma3:4b', 'size': 1},
        ],
      },
    );
    final container = buildContainer();
    final notifier = container.read(chatStateProvider.notifier);

    notifier.updateEndpoint('http://127.0.0.1:${server.port}');
    await notifier.refreshModels();

    final state = container.read(chatStateProvider);
    expect(state.availableModels.map((model) => model.name), [
      'gemma3:4b',
      'zeta:latest',
    ]);
    expect(state.selectedModel, 'gemma3:4b');
    expect(state.errorMessage, isNull);
  });

  test('sends chat history to the Ollama chat endpoint', () async {
    await startServer(
      tagsBody: {
        'models': [
          {'name': 'llama3.2'},
        ],
      },
    );
    final container = buildContainer();
    final notifier = container.read(chatStateProvider.notifier);

    notifier.updateEndpoint('http://127.0.0.1:${server.port}');
    await notifier.refreshModels();
    notifier.textEditingController.text = 'Hello';
    await notifier.sendMessage();
    notifier.textEditingController.text = 'Again';
    await notifier.sendMessage();

    expect(chatRequests, hasLength(2));
    expect(chatRequests.last['model'], 'llama3.2');
    expect(chatRequests.last['stream'], false);
    expect(chatRequests.last['messages'], [
      {'role': 'user', 'content': 'Hello'},
      {'role': 'assistant', 'content': 'Pong'},
      {'role': 'user', 'content': 'Again'},
    ]);
    expect(container.read(chatStateProvider).lastTokensPerSecond, 4);
  });

  test('uploads small text files as prompt context', () async {
    await startServer(
      tagsBody: {
        'models': [
          {'name': 'llama3.2'},
        ],
      },
    );
    final container = buildContainer();
    final notifier = container.read(chatStateProvider.notifier);

    notifier.updateEndpoint('http://127.0.0.1:${server.port}');
    await notifier.refreshModels();
    notifier.textEditingController.text = 'Summarize this';
    await notifier.uploadFile(PlatformFile(
      name: 'note.txt',
      size: 11,
      bytes: Uint8List.fromList(utf8.encode('hello world')),
    ));

    final content =
        (chatRequests.single['messages'] as List).single['content'] as String;
    expect(content, contains('Summarize this'));
    expect(content, contains('Attached file `note.txt`'));
    expect(content, contains('hello world'));
    expect(container.read(chatStateProvider).messages.first.text,
        contains('Attached `note.txt`'));
  });

  test('reports oversized files before sending a chat request', () async {
    await startServer();
    final container = buildContainer();
    final notifier = container.read(chatStateProvider.notifier);

    await notifier.uploadFile(PlatformFile(
      name: 'large.txt',
      size: 1024 * 1024 + 1,
      bytes: Uint8List(4),
    ));

    expect(chatRequests, isEmpty);
    expect(container.read(chatStateProvider).errorMessage, contains('larger'));
  });
}
