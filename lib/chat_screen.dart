import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_message.dart';
import 'chat_state.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: colorScheme.surface,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatState.messages.reversed
                            .toList()[chatState.messages.length - 1 - index];
                        return ChatMessageWidget(message: message);
                      },
                    ),
                  ),
                ),
                if (chatState.isLoading)
                  LinearProgressIndicator(
                    color: colorScheme.secondary,
                    backgroundColor: colorScheme.secondaryContainer,
                  ),
                Container(
                  color: colorScheme.surfaceContainerLow,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        color: colorScheme.primary,
                        onPressed: () async {
                          FilePickerResult? result =
                              await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                          );
                          if (result != null) {
                            ref
                                .read(chatStateProvider.notifier)
                                .uploadFile(result.files.first);
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: chatState.textEditingController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          onSubmitted: (value) => ref
                              .read(chatStateProvider.notifier)
                              .sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        mini: true,
                        child: const Icon(Icons.send),
                        onPressed: () =>
                            ref.read(chatStateProvider.notifier).sendMessage(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
