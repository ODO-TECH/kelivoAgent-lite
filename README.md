# KelivoAgent-lite

KelivoAgent-lite is a Windows PC coding-agent client based on Kelivo. This repository is the project fork and documents the features maintained in this fork, rather than the upstream Kelivo product.

## Project Focus

- Windows desktop first. Mobile platform directories remain in the source tree for compatibility, but are not the primary distribution target.
- Pi Agent is the default agent runtime. Users can choose whether to update the bundled Pi Agent kernel.
- The default agent system prompt follows Pi Agent's concise official-style prompt.

## Features Added In This Fork

### Agent And Workspaces

- Create, select, and manage working directories from the desktop application.
- Workspace-aware file browsing, file editing, approved command execution, and tool calls.
- Pi Agent sidecar integration for autonomous agent workflows.
- Optional Pi Agent kernel update controlled by the user.

### Shells

- PowerShell.
- Windows Command Prompt.
- Git Bash.
- A custom shell executable path selected by the user.

### Composer Syntax

- Codex-style `/command` syntax.
- Codex-style `$skill-name` syntax.
- Commands and skills are highlighted in the chat composer without changing the text sent to the model.

### Skills And Prompt Tools

- Skill Creator is preinstalled for creating and maintaining skills.
- PaddleOCR skill is preinstalled and can be enabled or disabled from settings.
- Configurable OCR API key support.
- Prompt optimization through a separately configurable optimization model.
- Pi Agent-compatible default system prompt.


## Build On Windows

Requirements:

- Flutter stable with Windows desktop support.
- Visual Studio with the Desktop development with C++ workload.
- Bun, if rebuilding the Pi Agent sidecar.

```powershell
cd kelivo-master
flutter pub get
flutter build windows --release --no-pub
```

The Windows executable is generated at:

```text
build/windows/x64/runner/Release/kelivo.exe
```

To build the sidecar:

```powershell
cd agent-sidecar
bun install
bun run build
bun run smoke
```

## Repository Layout

- `lib/`: Flutter application and desktop agent features.
- `agent-sidecar/`: Pi Agent sidecar bridge.
- `assets/skills/`: bundled skills, including Skill Creator and PaddleOCR.
- `test/`: unit and widget tests.
- `windows/`: Windows desktop runner.

## License And Attribution

KelivoAgent-lite is based on Kelivo. See `LICENSE` for the applicable license and attribution details.
