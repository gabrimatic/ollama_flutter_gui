import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ollama_flutter_gui/consts.dart';

import 'chat_message.dart';
import 'ollama_service.dart';

class ChatState {
  const ChatState({
    required this.messages,
    required this.isLoading,
    required this.availableModels,
    required this.selectedModel,
    required this.endpoint,
    this.statusMessage,
    this.errorMessage,
    this.lastTokensPerSecond,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final List<OllamaModel> availableModels;
  final String selectedModel;
  final String endpoint;
  final String? statusMessage;
  final String? errorMessage;
  final double? lastTokensPerSecond;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    List<OllamaModel>? availableModels,
    String? selectedModel,
    String? endpoint,
    String? statusMessage,
    String? errorMessage,
    double? lastTokensPerSecond,
    bool clearError = false,
    bool clearStatus = false,
    bool clearStats = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      availableModels: availableModels ?? this.availableModels,
      selectedModel: selectedModel ?? this.selectedModel,
      endpoint: endpoint ?? this.endpoint,
      statusMessage: clearStatus ? null : statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastTokensPerSecond:
          clearStats ? null : lastTokensPerSecond ?? this.lastTokensPerSecond,
    );
  }
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

class ChatStateNotifier extends Notifier<ChatState> {
  final textEditingController = TextEditingController();
  final endpointController = TextEditingController(text: kDefaultOllamaBaseUrl);

  @override
  ChatState build() {
    ref.onDispose(() {
      textEditingController.dispose();
      endpointController.dispose();
    });

    return const ChatState(
      messages: [],
      isLoading: false,
      availableModels: [],
      selectedModel: kDefaultAiModel,
      endpoint: kDefaultOllamaBaseUrl,
      statusMessage: 'Connect to Ollama to load local models.',
    );
  }

  OllamaClient _client() {
    return OllamaClient(
      baseUrl: state.endpoint,
      httpClient: ref.read(httpClientProvider),
    );
  }

  Future<void> refreshModels() async {
    state = state.copyWith(
      isLoading: true,
      statusMessage: 'Checking Ollama at ${state.endpoint}...',
      clearError: true,
    );

    try {
      final models = await _client().listModels();
      final modelNames = models.map((model) => model.name).toSet();
      final selectedModel = modelNames.contains(state.selectedModel)
          ? state.selectedModel
          : models.firstOrNull?.name ?? state.selectedModel;

      state = state.copyWith(
        isLoading: false,
        availableModels: models,
        selectedModel: selectedModel,
        statusMessage: models.isEmpty
            ? 'Ollama is reachable, but no local models were found.'
            : 'Loaded ${models.length} local model${models.length == 1 ? '' : 's'}.',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Ollama is not reachable at ${state.endpoint}. Start Ollama or set the right endpoint.',
        statusMessage: error.toString(),
      );
    }
  }

  void updateEndpoint(String value) {
    final endpoint = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (endpoint.isEmpty || endpoint == state.endpoint) return;

    endpointController.text = endpoint;
    state = state.copyWith(
      endpoint: endpoint,
      availableModels: const [],
      statusMessage: 'Endpoint changed. Refresh models to reconnect.',
      clearError: true,
      clearStats: true,
    );
  }

  void selectModel(String? modelName) {
    final model = modelName?.trim();
    if (model == null || model.isEmpty) return;

    state = state.copyWith(
      selectedModel: model,
      statusMessage: 'Using $model.',
      clearError: true,
      clearStats: true,
    );
  }

  void clearChat() {
    state = state.copyWith(
      messages: const [],
      statusMessage: 'Chat cleared.',
      clearError: true,
      clearStats: true,
    );
  }

  Future<void> sendMessage() async {
    final message = textEditingController.text.trim();
    if (message.isEmpty) return;

    await _processMessage(message: message);
  }

  Future<void> uploadFile(PlatformFile file) async {
    final currentInstruction = textEditingController.text.trim();
    final instruction = currentInstruction.isEmpty
        ? 'Read this file and summarize the useful parts.'
        : currentInstruction;

    try {
      if (file.bytes == null) {
        throw Exception('Could not read ${file.name}.');
      }

      if (file.size > kMaxUploadBytes) {
        throw Exception('${file.name} is larger than 1 MB.');
      }

      await _processMessage(
        message: '''
$instruction

Attached file `${file.name}`:

```text
${utf8.decode(file.bytes!, allowMalformed: true)}
```''',
        visibleMessage: 'Attached `${file.name}`\n\n$instruction',
      );
    } catch (error) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            text: 'File upload failed: $error',
            role: ChatRole.assistant,
            createdAt: DateTime.now(),
          ),
        ],
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> _processMessage({
    required String message,
    String? visibleMessage,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      statusMessage: 'Sending to ${state.selectedModel}...',
      clearError: true,
    );
    textEditingController.clear();

    final userMessage = ChatMessage(
      text: visibleMessage ?? message,
      role: ChatRole.user,
      createdAt: DateTime.now(),
    );
    final previousMessages = state.messages;
    final nextMessages = [...previousMessages, userMessage];
    state = state.copyWith(messages: nextMessages);

    try {
      final response = await _client().chat(
        model: state.selectedModel,
        messages: [
          ...previousMessages.map((message) => message.toOllamaMessage()),
          {
            'role': 'user',
            'content': message,
          },
        ],
      );

      final aiMessage = ChatMessage(
        text: response.content,
        role: ChatRole.assistant,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...nextMessages, aiMessage],
        isLoading: false,
        statusMessage: 'Response ready.',
        lastTokensPerSecond: _tokensPerSecond(response),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        messages: [
          ...nextMessages,
          ChatMessage(
            text:
                'I could not get a response from Ollama. Check that the server is running, the endpoint is correct, and `${state.selectedModel}` is pulled locally.\n\n$error',
            role: ChatRole.assistant,
            createdAt: DateTime.now(),
          ),
        ],
        errorMessage: error.toString(),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  double? _tokensPerSecond(OllamaChatResponse response) {
    final evalCount = response.evalCount;
    final evalDuration = response.evalDuration;
    if (evalCount == null || evalDuration == null || evalDuration == 0) {
      return null;
    }

    return evalCount / evalDuration * 1000000000;
  }
}

final chatStateProvider = NotifierProvider<ChatStateNotifier, ChatState>(
  ChatStateNotifier.new,
);
