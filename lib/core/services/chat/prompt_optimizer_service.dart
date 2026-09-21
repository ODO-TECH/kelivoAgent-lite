import '../api/chat_api_service.dart';
import '../../providers/settings_provider.dart';

/// Calls the optional prompt-editing model and returns a clean replacement.
/// Network failures are surfaced to the caller so the composer can preserve
/// the original draft and show a useful, non-destructive error.
class PromptOptimizerService {
  const PromptOptimizerService();

  Future<String> optimize({
    required SettingsProvider settings,
    required String draft,
    String? conversationId,
  }) async {
    final text = draft.trim();
    if (text.isEmpty) return draft;
    final provider = settings.promptOptimizeModelProvider;
    final model = settings.promptOptimizeModelId;
    if (provider == null || model == null) {
      throw StateError('Prompt optimizer model is not configured');
    }
    final config = settings.getProviderConfig(provider);
    final prompt = settings.promptOptimizePrompt.replaceAll('{content}', text);
    final result = await ChatApiService.generateMessage(
      config: config,
      modelId: model,
      conversationId: conversationId,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      maxTokens: 4096,
      builtInSearchOnly: true,
      allowImagesApiRouting: false,
      skipImageParsing: true,
    );
    final optimized = result.text.trim();
    if (optimized.isEmpty)
      throw StateError('Prompt optimizer returned empty text');
    return optimized;
  }
}
