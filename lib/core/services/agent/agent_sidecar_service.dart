import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/mcp_structured_image.dart';
import '../api/chat_api_helpers.dart';
import '../api/provider_request_headers.dart';
import '../api/stream/stream_chunk.dart';
import '../../models/token_usage.dart';
import '../../providers/settings_provider.dart';
import 'kelivo_agent_prompt.dart';

/// Windows-only bridge to the TypeScript pi Agent sidecar.
///
/// The sidecar owns the Agent loop. Kelivo remains the authority for tool
/// execution: every tool request is sent back through [onToolCall], so the
/// existing workspace boundary and approval services are preserved.
class AgentSidecarService {
  AgentSidecarService({this.sidecarExecutable, this.sidecarDirectory});

  final String? sidecarExecutable;
  final String? sidecarDirectory;

  static const _textId = 'agent-text';
  static const _reasoningId = 'agent-reasoning';

  Stream<StreamChunk> run({
    required String requestId,
    required String cwd,
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    required String prompt,
    required List<Map<String, dynamic>> tools,
    ToolCallHandler? onToolCall,
    String? systemPrompt,
    String? paddleOcrApiKey,
    bool? useResponseApi,
  }) {
    final controller = StreamController<StreamChunk>();
    unawaited(
      _run(
        requestId: requestId,
        cwd: cwd,
        config: config,
        modelId: modelId,
        messages: messages,
        prompt: prompt,
        tools: tools,
        onToolCall: onToolCall,
        systemPrompt: systemPrompt,
        paddleOcrApiKey: paddleOcrApiKey,
        useResponseApi: useResponseApi,
        controller: controller,
      ),
    );
    return controller.stream;
  }

  Future<void> _run({
    required String requestId,
    required String cwd,
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    required String prompt,
    required List<Map<String, dynamic>> tools,
    required ToolCallHandler? onToolCall,
    required String? systemPrompt,
    required String? paddleOcrApiKey,
    required bool? useResponseApi,
    required StreamController<StreamChunk> controller,
  }) async {
    Process? process;
    controller.onCancel = () async {
      final active = process;
      if (active == null) return;
      try {
        active.stdin.writeln(
          jsonEncode({'type': 'abort', 'requestId': requestId}),
        );
        await active.stdin.flush();
      } catch (_) {}
      try {
        active.kill();
      } catch (_) {}
    };
    try {
      if (!Platform.isWindows) {
        throw UnsupportedError('The pi Agent sidecar is currently PC-only.');
      }
      process = await _startProcess(paddleOcrApiKey: paddleOcrApiKey);
      final input = process.stdin;
      final lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final headers = <String, String>{
        ...providerDefaultHeaders(config),
        for (final entry in config.customHeaders)
          if ((entry['name'] ?? '').trim().isNotEmpty)
            entry['name']!.trim(): entry['value'] ?? '',
      };
      final providerKind = switch (config.providerType) {
        ProviderKind.claude => 'claude',
        ProviderKind.google => 'google',
        _ => 'openai',
      };
      final request = <String, dynamic>{
        'type': 'start',
        'requestId': requestId,
        'cwd': cwd,
        'provider': {
          'kind': providerKind,
          'baseUrl': config.baseUrl,
          'apiKey': apiKeyForRequest(config, modelId),
          'modelId': apiModelId(config, modelId),
          'modelName': modelId,
          'headers': headers,
          'useResponseApi': useResponseApi ?? config.useResponseApi ?? false,
        },
        'prompt': prompt,
        'context': jsonEncode(messages),
        // Empty means "use pi's official resource-loader prompt". Preserve
        // explicitly customized assistant prompts.
        'systemPrompt':
            systemPrompt == null ||
                systemPrompt.trim() == kelivoAgentSystemPrompt
            ? ''
            : systemPrompt,
        'tools': tools,
      };
      input.writeln(jsonEncode(request));
      await input.flush();

      var finished = false;
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final event = jsonDecode(line) as Map<String, dynamic>;
        if (event['requestId'] != null && event['requestId'] != requestId) {
          continue;
        }
        final type = event['type']?.toString();
        switch (type) {
          case 'text_delta':
            final text = event['text']?.toString() ?? '';
            if (text.isNotEmpty) {
              controller.add(TextDelta(id: _textId, text: text));
            }
            break;
          case 'thinking_delta':
            final text = event['text']?.toString() ?? '';
            if (text.isNotEmpty) {
              controller.add(ReasoningDelta(id: _reasoningId, text: text));
            }
            break;
          case 'tool_call':
            final id = event['toolCallId']?.toString() ?? '';
            final name = event['name']?.toString() ?? '';
            final args = _map(event['arguments']);
            controller.add(ToolCallStart(id: id, toolName: name));
            controller.add(ToolCallDelta(id: id, inputDelta: jsonEncode(args)));
            controller.add(ToolCallEnd(id));
            final handler = onToolCall;
            Object? raw;
            if (handler == null) {
              raw = ClientToolResult(
                'Tool execution is unavailable in this Agent session.',
              );
            } else {
              try {
                raw = await handler(name, args, toolCallId: id);
              } catch (error) {
                raw = ClientToolResult('Tool failed: $error');
              }
            }
            final result = ClientToolResult.fromHandler(raw);
            controller.add(
              ToolCallResult(
                id: id,
                output: result.content,
                metadata: result.metadata,
              ),
            );
            input.writeln(
              jsonEncode({
                'type': 'tool_result',
                'requestId': requestId,
                'toolCallId': id,
                'content': result.content,
                if (result.metadata != null) 'metadata': result.metadata,
              }),
            );
            await input.flush();
            break;
          case 'message_end':
            final usage = _usage(event['usage']);
            if (usage != null) controller.add(Usage(usage));
            break;
          case 'finish':
            if (!finished) {
              finished = true;
              controller.add(const Finish(finishReason: 'stop'));
            }
            break;
          case 'error':
            throw StateError(
              event['message']?.toString() ?? 'Agent sidecar failed',
            );
        }
        if (finished) break;
      }
      if (!finished) controller.add(const Finish(finishReason: 'stop'));
    } catch (error, stack) {
      if (!controller.isClosed) controller.addError(error, stack);
    } finally {
      try {
        await process?.stdin.close();
      } catch (_) {}
      if (process != null) {
        try {
          process.kill();
        } catch (_) {}
        await process.exitCode;
      }
      await controller.close();
    }
  }

  Future<Process> _startProcess({String? paddleOcrApiKey}) async {
    final environment = <String, String>{
      ...Platform.environment,
      if (paddleOcrApiKey != null && paddleOcrApiKey.trim().isNotEmpty)
        'PADDLEOCR_API_KEY': paddleOcrApiKey.trim(),
    };
    final explicit =
        sidecarExecutable ?? Platform.environment['KELIVO_AGENT_SIDECAR'];
    if (explicit != null &&
        explicit.trim().isNotEmpty &&
        File(explicit).existsSync()) {
      return Process.start(
        explicit,
        const <String>[],
        environment: environment,
      );
    }
    final sibling = p.join(
      File(Platform.resolvedExecutable).parent.path,
      'kelivo-agent-sidecar.exe',
    );
    if (File(sibling).existsSync())
      return Process.start(sibling, const <String>[], environment: environment);

    final dir =
        sidecarDirectory ?? Platform.environment['KELIVO_AGENT_SIDECAR_DIR'];
    if (dir != null && Directory(dir).existsSync()) {
      return Process.start(
        'bun',
        const <String>['run', 'server.ts'],
        workingDirectory: dir,
        environment: environment,
      );
    }
    final localDir = p.join(Directory.current.path, 'agent-sidecar');
    if (Directory(localDir).existsSync()) {
      return Process.start(
        'bun',
        const <String>['run', 'server.ts'],
        workingDirectory: localDir,
        environment: environment,
      );
    }
    throw StateError(
      'Kelivo Agent sidecar was not found. Build kelivo-agent-sidecar.exe or set '
      'KELIVO_AGENT_SIDECAR_DIR to the agent-sidecar directory.',
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, value) => MapEntry('$key', value),
      );
    }
    return <String, dynamic>{};
  }

  static TokenUsage? _usage(Object? raw) {
    final value = _map(raw);
    if (value.isEmpty) return null;
    return TokenUsage(
      promptTokens: (value['input'] as num?)?.toInt() ?? 0,
      completionTokens: (value['output'] as num?)?.toInt() ?? 0,
      cachedTokens: (value['cacheRead'] as num?)?.toInt() ?? 0,
      totalTokens: (value['totalTokens'] as num?)?.toInt() ?? 0,
    );
  }
}
