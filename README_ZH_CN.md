# KelivoAgent-lite

KelivoAgent-lite 是一个基于 Kelivo 开发的 Windows PC 编程 Agent 客户端。本仓库是本项目自己的分支版本，文档只描述本分支实际维护的功能，不再沿用上游 Kelivo 的产品介绍和发布信息。

## 项目定位

- 以 Windows 桌面端为首要目标。移动平台目录仍保留在源码中用于兼容，但不作为本项目的主要发布目标。
- 默认使用 Pi Agent 内核作为 Agent 运行时，用户可以选择是否更新 Pi Agent 内核。
- 默认 Agent 系统提示词采用 Pi Agent 官方风格的精简提示词。

## 本分支新增功能

### Agent 与工作目录

- 可以在桌面端创建、选择和管理工作目录。
- 支持工作目录内的文件浏览、文件编辑、授权命令执行和工具调用。
- 集成 Pi Agent sidecar，支持自主 Agent 工作流。
- 支持由用户控制的 Pi Agent 内核更新。

### Shell

- PowerShell。
- Windows 命令提示符。
- Git Bash。
- 用户自定义 Shell 可执行文件路径。

### 输入语法

- 支持 Codex 风格的 `/command` 命令语法。
- 支持 Codex 风格的 `$skill-name` skill 语法。
- 聊天输入框会高亮命令和 skill，但不会修改发送给模型的原始文本。

### Skill 与提示词工具

- 预装 Skill Creator，用于创建和维护 skill。
- 预装 PaddleOCR skill，可以在设置中开启或关闭。
- 支持配置 OCR API Key。
- 支持配置独立的提示词优化模型。
- 默认系统提示词与 Pi Agent 风格保持一致。


## Windows 构建

环境要求：

- 支持 Windows 桌面端的 Flutter stable。
- 安装了 Desktop development with C++ 工作负载的 Visual Studio。
- 如果需要重新构建 Pi Agent sidecar，需要安装 Bun。

```powershell
cd kelivo-master
flutter pub get
flutter build windows --release --no-pub
```

Windows 可执行文件生成在：

```text
build/windows/x64/runner/Release/kelivo.exe
```

构建 sidecar：

```powershell
cd agent-sidecar
bun install
bun run build
bun run smoke
```

## 目录说明

- `lib/`：Flutter 应用和桌面 Agent 功能。
- `agent-sidecar/`：Pi Agent sidecar 桥接程序。
- `assets/skills/`：内置 skill，包括 Skill Creator 和 PaddleOCR。
- `test/`：单元测试和组件测试。
- `windows/`：Windows 桌面端 runner。

## 许可证与来源

KelivoAgent-lite 基于 Kelivo 开发。适用的许可证和来源说明见 `LICENSE`。
