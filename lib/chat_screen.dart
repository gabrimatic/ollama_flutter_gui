import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_message.dart';
import 'chat_state.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(chatStateProvider.notifier).refreshModels());
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    final notifier = ref.read(chatStateProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              children: [
                _Header(
                  state: chatState,
                  notifier: notifier,
                ),
                if (chatState.errorMessage != null)
                  _StatusBanner(
                    icon: Icons.error_outline,
                    message: chatState.errorMessage!,
                    color: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  )
                else if (chatState.statusMessage != null)
                  _StatusBanner(
                    icon: Icons.info_outline,
                    message: chatState.statusMessage!,
                    color: colorScheme.surfaceContainerHigh,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                if (chatState.isLoading)
                  LinearProgressIndicator(
                    color: colorScheme.secondary,
                    backgroundColor: colorScheme.secondaryContainer,
                  ),
                Expanded(
                  child: chatState.messages.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: chatState.messages.length,
                          itemBuilder: (context, index) {
                            return ChatMessageWidget(
                              message: chatState.messages[index],
                            );
                          },
                        ),
                ),
                _Composer(
                  isLoading: chatState.isLoading,
                  notifier: notifier,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.notifier,
  });

  final ChatState state;
  final ChatStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelNames = {
      state.selectedModel,
      ...state.availableModels.map((model) => model.name),
    }.where((model) => model.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ollama Flutter GUI',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh models',
                onPressed: state.isLoading
                    ? null
                    : () {
                        notifier
                            .updateEndpoint(notifier.endpointController.text);
                        notifier.refreshModels();
                      },
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Clear chat',
                onPressed: state.messages.isEmpty || state.isLoading
                    ? null
                    : notifier.clearChat,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final endpoint = TextField(
                controller: notifier.endpointController,
                decoration: const InputDecoration(
                  labelText: 'Ollama endpoint',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (value) {
                  notifier.updateEndpoint(value);
                  notifier.refreshModels();
                },
              );
              final modelPicker = DropdownButtonFormField<String>(
                initialValue: state.selectedModel,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.memory),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: modelNames
                    .map(
                      (model) => DropdownMenuItem(
                        value: model,
                        child: Text(model, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: state.isLoading ? null : notifier.selectModel,
              );

              if (compact) {
                return Column(
                  children: [
                    endpoint,
                    const SizedBox(height: 10),
                    modelPicker,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: endpoint),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: modelPicker),
                ],
              );
            },
          ),
          if (state.lastTokensPerSecond != null) ...[
            const SizedBox(height: 8),
            Text(
              '${state.lastTokensPerSecond!.toStringAsFixed(1)} tokens/sec',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.foregroundColor,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: foregroundColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 42,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Chat with a local Ollama model',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start Ollama, pull a model, then send a prompt or attach a small text file.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.isLoading,
    required this.notifier,
  });

  final bool isLoading;
  final ChatStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attach text file',
            icon: const Icon(Icons.attach_file),
            color: colorScheme.primary,
            onPressed: isLoading
                ? null
                : () async {
                    final result = await FilePicker.pickFiles(
                      allowMultiple: false,
                      withData: true,
                    );
                    if (result != null) {
                      notifier.uploadFile(result.files.first);
                    }
                  },
          ),
          Expanded(
            child: TextField(
              controller: notifier.textEditingController,
              minLines: 1,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Ask something local...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => notifier.sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            icon: const Icon(Icons.send),
            onPressed: isLoading ? null : notifier.sendMessage,
          ),
        ],
      ),
    );
  }
}
