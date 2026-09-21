import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/home/widgets/agent_syntax_highlighting_controller.dart';

void main() {
  testWidgets('renders commands and skills with distinct theme colors', (
    tester,
  ) async {
    final controller = AgentSyntaxHighlightingController(
      text: r'/help use $skill-creator',
    );
    late TextSpan span;
    late Color primary;
    late Color tertiary;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            primary = Theme.of(context).colorScheme.primary;
            tertiary = Theme.of(context).colorScheme.tertiary;
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 14),
              withComposing: true,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    final children = span.children!.whereType<TextSpan>().toList();
    final command = children.singleWhere((child) => child.text == '/help');
    final skill = children.singleWhere(
      (child) => child.text == r'$skill-creator',
    );

    expect(command.style!.color, primary);
    expect(skill.style!.color, tertiary);
    expect(command.style!.fontWeight, FontWeight.w600);
    expect(skill.style!.fontWeight, FontWeight.w600);
  });

  testWidgets('preserves the composing underline on highlighted syntax', (
    tester,
  ) async {
    final controller = AgentSyntaxHighlightingController(
      value: const TextEditingValue(
        text: r'/help $skill-creator',
        composing: TextRange(start: 6, end: 20),
      ),
    );
    late TextSpan span;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 14),
              withComposing: true,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    final skill = span.children!.whereType<TextSpan>().singleWhere(
      (child) => child.text == r'$skill-creator',
    );

    expect(skill.style!.decoration, TextDecoration.underline);
  });
}
