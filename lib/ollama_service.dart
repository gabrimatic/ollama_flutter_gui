import 'dart:convert';

import 'package:http/http.dart' as http;

class OllamaApiException implements Exception {
  const OllamaApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OllamaModel {
  const OllamaModel({
    required this.name,
    this.size,
    this.modifiedAt,
  });

  final String name;
  final int? size;
  final DateTime? modifiedAt;

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String? ?? '',
      size: json['size'] as int?,
      modifiedAt: DateTime.tryParse(json['modified_at'] as String? ?? ''),
    );
  }
}

class OllamaChatResponse {
  const OllamaChatResponse({
    required this.content,
    this.evalCount,
    this.evalDuration,
  });

  final String content;
  final int? evalCount;
  final int? evalDuration;

  factory OllamaChatResponse.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    final content = message is Map<String, dynamic>
        ? message['content'] as String?
        : json['response'] as String?;

    return OllamaChatResponse(
      content: content?.trim() ?? '',
      evalCount: json['eval_count'] as int?,
      evalDuration: json['eval_duration'] as int?,
    );
  }
}

class OllamaClient {
  OllamaClient({
    required String baseUrl,
    http.Client? httpClient,
  })  : _baseUri = Uri.parse(baseUrl),
        _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Uri _uri(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.replace(
      pathSegments: [
        ..._baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        ...cleanPath.split('/'),
      ],
    );
  }

  Future<List<OllamaModel>> listModels() async {
    final response = await _httpClient.get(_uri('/api/tags'));
    final body = _decodeObject(response.body);

    if (response.statusCode != 200) {
      throw OllamaApiException(_errorMessage(response.statusCode, body));
    }

    final models = body['models'];
    if (models is! List) return const [];

    return models
        .whereType<Map<String, dynamic>>()
        .map(OllamaModel.fromJson)
        .where((model) => model.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<OllamaChatResponse> chat({
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/chat'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'stream': false,
      }),
    );
    final body = _decodeObject(response.body);

    if (response.statusCode != 200) {
      throw OllamaApiException(_errorMessage(response.statusCode, body));
    }

    final chatResponse = OllamaChatResponse.fromJson(body);
    if (chatResponse.content.isEmpty) {
      throw const OllamaApiException('Ollama returned an empty response.');
    }

    return chatResponse;
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return const {};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;

    throw const OllamaApiException('Ollama returned an unexpected response.');
  }

  String _errorMessage(int statusCode, Map<String, dynamic> body) {
    final error = body['error'];
    if (error is String && error.trim().isNotEmpty) {
      return 'Ollama error $statusCode: $error';
    }

    return 'Ollama request failed with HTTP $statusCode.';
  }
}
