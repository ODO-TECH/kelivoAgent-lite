let calls = 0;
let firstPayload: any;
const server = Bun.serve({
  port: 0,
  fetch: async (request) => {
    if (!request.url.endsWith('/chat/completions')) return new Response('not found', { status: 404 });
    const raw = await request.text();
    calls += 1;
    if (calls === 1) {
      firstPayload = JSON.parse(raw);
      const body = [
        'data: ' + JSON.stringify({ id: 'smoke', object: 'chat.completion.chunk', choices: [{ index: 0, delta: { role: 'assistant', tool_calls: [{ index: 0, id: 'call1', type: 'function', function: { name: 'list_dir', arguments: '{"path":"."}' } }] }, finish_reason: 'tool_calls' }] }),
        '',
        'data: [DONE]',
        '',
      ].join('\n');
      return new Response(body, { headers: { 'Content-Type': 'text/event-stream' } });
    }
    const body = [
      'data: ' + JSON.stringify({ id: 'smoke', object: 'chat.completion.chunk', choices: [{ index: 0, delta: { role: 'assistant', content: 'sidecar ok' }, finish_reason: null }] }),
      '',
      'data: ' + JSON.stringify({ id: 'smoke', object: 'chat.completion.chunk', choices: [{ index: 0, delta: {}, finish_reason: 'stop' }] }),
      '',
      'data: [DONE]',
      '',
    ].join('\n');
    return new Response(body, { headers: { 'Content-Type': 'text/event-stream' } });
  },
});

const childCommand = process.env.KELIVO_SMOKE_EXE
  ? [process.env.KELIVO_SMOKE_EXE]
  : ['bun', 'run', 'server.ts'];
const child = Bun.spawn(childCommand, {
  stdin: 'pipe',
  stdout: 'pipe',
  stderr: 'inherit',
});
const request = {
  type: 'start',
  requestId: 'smoke',
  cwd: process.cwd(),
  provider: {
    kind: 'openai',
    baseUrl: `http://127.0.0.1:${server.port}`,
    apiKey: 'smoke-key',
    modelId: 'smoke-model',
  },
  prompt: 'say hello',
  context: JSON.stringify([
    { role: 'system', content: 'SYSTEM-CHECK' },
    { role: 'user', content: 'previous request' },
    { role: 'user', content: 'say hello' },
  ]),
  systemPrompt: 'SYSTEM-CHECK',
  tools: [{ type: 'function', function: { name: 'list_dir', description: 'List a directory', parameters: { type: 'object', properties: { path: { type: 'string' } }, required: ['path'] } } }],
};
child.stdin.write(JSON.stringify(request) + '\n');
await child.stdin.flush();
for await (const line of child.stdout) {
  const text = new TextDecoder().decode(line);
  process.stdout.write(text);
  if (text.includes('"type":"tool_call"')) {
    child.stdin.write(JSON.stringify({ type: 'tool_result', requestId: 'smoke', toolCallId: 'call1', content: 'file.txt' }) + '\n');
    await child.stdin.flush();
  }
  if (text.includes('"type":"finish"')) break;
}
child.kill();
server.stop();

const messages = Array.isArray(firstPayload?.messages) ? firstPayload.messages : [];
if (!messages.some((message: any) =>
  (message.role === 'system' || message.role === 'developer') &&
  String(message.content).includes('SYSTEM-CHECK'))
) {
  throw new Error(`system prompt was not sent as a system message: ${JSON.stringify(messages)}`);
}
if (messages.some((message: any) =>
  message.role === 'user' && String(message.content).includes('SYSTEM-CHECK')
)) {
  throw new Error('system prompt was duplicated into the user message');
}
