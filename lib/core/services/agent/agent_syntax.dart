/// Syntax tokens recognized by the chat composer for agent workflows.
enum AgentSyntaxKind { command, skill }

/// A command or skill reference embedded in the user's composer text.
class AgentSyntaxToken {
  const AgentSyntaxToken({
    required this.kind,
    required this.start,
    required this.end,
    required this.name,
  });

  final AgentSyntaxKind kind;
  final int start;
  final int end;
  final String name;

  String get raw => '${kind == AgentSyntaxKind.command ? '/' : r'$'}$name';
}

/// Finds Codex-style `/command` and `$skill-name` references.
///
/// Tokens must start at the beginning of a line or after whitespace. This
/// keeps ordinary text, Windows paths, and paths such as `/workspace/file`
/// from being interpreted as agent syntax.
List<AgentSyntaxToken> parseAgentSyntax(String text) {
  if (text.isEmpty) return const <AgentSyntaxToken>[];

  final matches = RegExp(
    r'(^|[\s])([/$])([A-Za-z][A-Za-z0-9_-]*)(?![A-Za-z0-9_/-])',
    multiLine: true,
  ).allMatches(text);

  return <AgentSyntaxToken>[
    for (final match in matches)
      AgentSyntaxToken(
        kind: match.group(2) == '/'
            ? AgentSyntaxKind.command
            : AgentSyntaxKind.skill,
        start: match.start + (match.group(1)?.length ?? 0),
        end: match.end,
        name: match.group(3)!,
      ),
  ];
}
