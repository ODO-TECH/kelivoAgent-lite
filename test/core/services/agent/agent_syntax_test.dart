import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/agent/agent_syntax.dart';

void main() {
  group('parseAgentSyntax', () {
    test('finds commands and skills at valid boundaries', () {
      const input = '/help inspect \$skill-creator\n/compact with \$paddleocr';

      final tokens = parseAgentSyntax(input);

      expect(
        tokens.map((token) => (token.kind, token.raw)).toList(),
        equals([
          (AgentSyntaxKind.command, '/help'),
          (AgentSyntaxKind.skill, r'$skill-creator'),
          (AgentSyntaxKind.command, '/compact'),
          (AgentSyntaxKind.skill, r'$paddleocr'),
        ]),
      );
      expect(
        tokens.map((token) => input.substring(token.start, token.end)),
        everyElement(
          isIn(<String>['/help', r'$skill-creator', '/compact', r'$paddleocr']),
        ),
      );
    });

    test('does not treat paths or embedded values as syntax', () {
      const input =
          r'Open /workspace/file.txt and C:/work. Use email$skill and /tool/run.';

      expect(parseAgentSyntax(input), isEmpty);
    });
  });
}
