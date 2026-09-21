# Kelivo Agent Sidecar

The Windows Agent runtime is a small JSONL bridge around pi's `AgentSession`.
Kelivo owns workspace tools and approvals; the sidecar only owns the Agent loop.

Development:

```powershell
npm install
bun run server.ts
```

Build the Windows executable:

```powershell
bun run build
```

When running Flutter from the repository root, Kelivo discovers `agent-sidecar`
automatically. Packaged builds should place `kelivo-agent-sidecar.exe` next to
the Kelivo executable, or set `KELIVO_AGENT_SIDECAR` / `KELIVO_AGENT_SIDECAR_DIR`.
