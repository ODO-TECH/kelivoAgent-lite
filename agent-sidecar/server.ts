import { createInterface } from "node:readline";
import { registerBuiltInApiProviders } from "@mariozechner/pi-ai";
import {
  AuthStorage,
  createAgentSession,
  DefaultResourceLoader,
  ModelRegistry,
  SessionManager,
  SettingsManager,
} from "@mariozechner/pi-coding-agent";
import type { ToolDefinition } from "@mariozechner/pi-coding-agent";

type JsonObject = Record<string, unknown>;

type StartRequest = {
  type: "start";
  requestId: string;
  cwd: string;
  provider: {
    kind: "openai" | "claude" | "google";
    baseUrl: string;
    apiKey: string;
    modelId: string;
    modelName?: string;
    headers?: Record<string, string>;
    useResponseApi?: boolean;
  };
  prompt: string;
  context?: string;
  systemPrompt?: string;
  thinkingLevel?: string;
  tools?: Array<{
    type: "function";
    function: { name: string; description?: string; parameters?: JsonObject };
  }>;
};

type ToolResultMessage = {
  type: "tool_result";
  requestId: string;
  toolCallId: string;
  content: string;
  metadata?: unknown;
};

type AbortRequest = { type: "abort"; requestId: string };
type Incoming = StartRequest | ToolResultMessage | AbortRequest;

const pendingToolResults = new Map<string, (message: ToolResultMessage) => void>();
const activeSessions = new Map<string, { abort: () => Promise<void> }>();

registerBuiltInApiProviders();

function write(message: JsonObject): void {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function apiFor(kind: StartRequest["provider"]["kind"], useResponseApi?: boolean): string {
  if (kind === "claude") return "anthropic-messages";
  if (kind === "google") return "google-generative-ai";
  return useResponseApi ? "openai-responses" : "openai-completions";
}

function modelFor(request: StartRequest): any {
  const provider = request.provider;
  const api = apiFor(provider.kind, provider.useResponseApi);
  return {
    id: provider.modelId,
    name: provider.modelName || provider.modelId,
    api,
    provider: "kelivo",
    baseUrl: provider.baseUrl.replace(/\/$/, ""),
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 128000,
    maxTokens: 16384,
    ...(provider.headers ? { headers: provider.headers } : {}),
    ...(api === "openai-completions" ? { compat: { supportsStore: false } } : {}),
    // pi's built-in providers read the API key through the model registry. The
    // sidecar keeps the key in an ephemeral environment variable per request.
  };
}

function toolSchema(tool: NonNullable<StartRequest["tools"]>[number]): any {
  return tool.function.parameters ?? { type: "object", properties: {} };
}

function proxyTools(request: StartRequest): ToolDefinition[] {
  return (request.tools ?? []).map((tool) => ({
    name: tool.function.name,
    label: tool.function.name,
    description: tool.function.description ?? tool.function.name,
    parameters: toolSchema(tool) as any,
    executionMode: "sequential",
    async execute(toolCallId, params) {
      write({
        type: "tool_call",
        requestId: request.requestId,
        toolCallId,
        name: tool.function.name,
        arguments: params,
      });
      const result = await new Promise<ToolResultMessage>((resolve) => {
        pendingToolResults.set(`${request.requestId}:${toolCallId}`, resolve);
      });
      return {
        content: [{ type: "text", text: result.content }],
        details: result.metadata ?? {},
      } as any;
    },
  })) as ToolDefinition[];
}

function contextPrompt(request: StartRequest): string {
  let context = request.context?.trim();
  if (context) {
    try {
      const messages = JSON.parse(context) as Array<Record<string, unknown>>;
      const lines: string[] = [];
      for (const message of messages.slice(0, -1)) {
        const role = String(message.role ?? "message");
        if (role === "system" || role === "developer") continue;
        const content = message.content;
        const text = typeof content === "string"
          ? content
          : Array.isArray(content)
            ? content.map((part: any) => part?.text ?? part?.content ?? JSON.stringify(part)).join("\n")
            : JSON.stringify(content ?? "");
        if (text.trim()) lines.push(`${role}:\n${text}`);
      }
      context = lines.join("\n\n");
    } catch {
      // Keep the original context if Kelivo sends a future transcript shape.
    }
  }
  return context
    ? `Conversation context:\n${context}\n\nUser request:\n${request.prompt}`
    : request.prompt;
}

async function run(request: StartRequest): Promise<void> {
  const model = modelFor(request);
  const authStorage = AuthStorage.inMemory();
  const modelRegistry = ModelRegistry.inMemory(authStorage);
  modelRegistry.registerProvider("kelivo", {
    name: "Kelivo",
    baseUrl: request.provider.baseUrl.replace(/\/$/, ""),
    apiKey: request.provider.apiKey || "unused",
    api: model.api,
    headers: request.provider.headers,
    models: [model],
  });
  const registeredModel = modelRegistry.find("kelivo", request.provider.modelId) ?? model;
  const manager = SessionManager.inMemory(request.cwd);
  const settingsManager = SettingsManager.inMemory({
    compaction: { enabled: true },
    retry: { enabled: true },
  });
  const resourceLoader = new DefaultResourceLoader({
    cwd: request.cwd,
    agentDir: request.cwd,
    settingsManager,
    // Leave this unset for the official pi prompt. A non-empty value is an
    // explicit user override and is still honored for custom assistants.
    systemPrompt: request.systemPrompt?.trim() || undefined,
    noExtensions: true,
    noSkills: true,
    noPromptTemplates: true,
    noThemes: true,
    noContextFiles: true,
  });
  await resourceLoader.reload();
  const { session } = await createAgentSession({
    cwd: request.cwd,
    model: registeredModel,
    authStorage,
    modelRegistry,
    sessionManager: manager,
    settingsManager,
    resourceLoader,
    noTools: "builtin",
    customTools: proxyTools(request),
  });

  activeSessions.set(request.requestId, { abort: () => session.abort() });
  write({ type: "started", requestId: request.requestId });
  const unsubscribe = session.subscribe((event: any) => {
    if (event.type === "message_update" && event.message?.role === "assistant") {
      const update = event.assistantMessageEvent;
      if (update?.type === "text_delta" && update.delta) {
        write({ type: "text_delta", requestId: request.requestId, text: update.delta });
      } else if (update?.type === "thinking_delta" && update.delta) {
        write({ type: "thinking_delta", requestId: request.requestId, text: update.delta });
      } else if ((update?.type === "toolcall_start" || update?.type === "toolcall_delta") && update.partial) {
        const call = update.partial.content?.[update.contentIndex];
        if (call?.type === "toolCall") {
          write({
            type: update.type,
            requestId: request.requestId,
            toolCallId: call.id,
            name: call.name,
            input: update.delta ?? "",
          });
        }
      } else if (update?.type === "toolcall_end" && update.toolCall) {
        write({
          type: "toolcall_end",
          requestId: request.requestId,
          toolCallId: update.toolCall.id,
          name: update.toolCall.name,
          arguments: update.toolCall.arguments ?? {},
        });
      }
    } else if (event.type === "tool_execution_start") {
      write({ type: "tool_execution_start", requestId: request.requestId, toolCallId: event.toolCallId, name: event.toolName });
    } else if (event.type === "tool_execution_end") {
      write({ type: "tool_execution_end", requestId: request.requestId, toolCallId: event.toolCallId, error: event.isError === true });
    } else if (event.type === "message_end" && event.message?.role === "assistant") {
      const usage = event.message.usage;
      write({
        type: "message_end",
        requestId: request.requestId,
        stopReason: event.message.stopReason ?? null,
        usage: usage
          ? { input: usage.input, output: usage.output, totalTokens: usage.totalTokens, cacheRead: usage.cacheRead }
          : null,
      });
    } else if (event.type === "compaction_start" || event.type === "compaction_end" || event.type === "auto_retry_start" || event.type === "auto_retry_end") {
      write({ type: event.type, requestId: request.requestId, ...event });
    }
  });

  try {
    await session.prompt(contextPrompt(request), { expandPromptTemplates: false });
    write({ type: "finish", requestId: request.requestId });
  } catch (error) {
    write({ type: "error", requestId: request.requestId, message: error instanceof Error ? error.message : String(error) });
  } finally {
    unsubscribe();
    activeSessions.delete(request.requestId);
    session.dispose();
    for (const key of [...pendingToolResults.keys()]) {
      if (key.startsWith(`${request.requestId}:`)) pendingToolResults.delete(key);
    }
  }
}

const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
input.on("line", (line) => {
  let message: Incoming;
  try {
    message = JSON.parse(line) as Incoming;
  } catch {
    write({ type: "error", message: "Invalid JSON request" });
    return;
  }
  if (message.type === "start") {
    void run(message);
    return;
  }
  if (message.type === "tool_result") {
    pendingToolResults.get(`${message.requestId}:${message.toolCallId}`)?.(message);
    pendingToolResults.delete(`${message.requestId}:${message.toolCallId}`);
    return;
  }
  if (message.type === "abort") {
    void activeSessions.get(message.requestId)?.abort();
  }
});
