import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final TextEditingController textEditingController;

  ChatState({
    required this.messages,
    required this.isLoading,
    required this.textEditingController,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      textEditingController: textEditingController,
    );
  }
}

class ChatStateNotifier extends StateNotifier<ChatState> {
  ChatStateNotifier() : super(ChatState(messages: [], isLoading: false, textEditingController: TextEditingController()));

  Future<void> sendMessage() async {
    final message = state.textEditingController.text.trim();
    if (message.isEmpty) return;

    await _processMessage(message);
  }

  Future<void> uploadFiles(List<PlatformFile> files) async {
    state = state.copyWith(isLoading: true);

    final fileNames = files.map((file) => file.name).join(', ');
    final userMessage = ChatMessage(text: "Uploaded files: $fileNames", isUser: true);
    state = state.copyWith(messages: [userMessage, ...state.messages]);

    try {
      for (var file in files) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('Failed to read file: ${file.name}');
        }

        // Instead of displaying content, we'll just send the file name to the API
        await _processMessage("Uploaded file: ${file.name}");
      }
    } catch (e) {
      state = state.copyWith(messages: [
        ChatMessage(text: 'An error occurred while processing the files. Please try again.', isUser: false),
        ...state.messages,
      ]);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _processMessage(String message) async {
    state = state.copyWith(isLoading: true);
    state.textEditingController.clear();

    final userMessage = ChatMessage(text: message, isUser: true);
    state = state.copyWith(messages: [userMessage, ...state.messages]);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'llama3.1',
          'prompt': message,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final aiMessage = ChatMessage(text: jsonResponse['response'], isUser: false);
        state = state.copyWith(messages: [aiMessage, ...state.messages]);
      } else {
        throw Exception('Failed to load response');
      }
    } catch (e) {
      state = state.copyWith(messages: [
        ChatMessage(text: 'An error occurred. Please try again.', isUser: false),
        ...state.messages,
      ]);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final chatStateProvider = StateNotifierProvider<ChatStateNotifier, ChatState>((ref) => ChatStateNotifier());