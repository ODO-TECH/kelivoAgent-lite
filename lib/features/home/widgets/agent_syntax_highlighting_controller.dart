import 'package:flutter/material.dart';

import '../../../core/services/agent/agent_syntax.dart';

/// A composer controller that renders agent commands and skill references.
///
/// It preserves the supplied text and selection exactly. The styling exists
/// only in [buildTextSpan], so pasted content and submitted messages retain
/// their original plain-text form.
class AgentSyntaxHighlightingController extends TextEditingController {
  AgentSyntaxHighlightingController({String? text, TextEditingValue? value})
    : assert(text == null || value == null),
      super.fromValue(value ?? TextEditingValue(text: text ?? ''));

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    final tokens = parseAgentSyntax(text);
    if (tokens.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final composing = value.composing;
    final hasComposing =
        withComposing &&
        composing.start >= 0 &&
        composing.end >= composing.start &&
        composing.end <= text.length;
    final boundaries = <int>{0, text.length};
    for (final token in tokens) {
      boundaries
        ..add(token.start)
        ..add(token.end);
    }
    if (hasComposing) {
      boundaries
        ..add(composing.start)
        ..add(composing.end);
    }

    final orderedBoundaries = boundaries.toList()..sort();
    final colorScheme = Theme.of(context).colorScheme;
    final children = <InlineSpan>[];
    for (var i = 0; i < orderedBoundaries.length - 1; i++) {
      final start = orderedBoundaries[i];
      final end = orderedBoundaries[i + 1];
      if (start == end) continue;

      TextStyle? segmentStyle;
      for (final token in tokens) {
        if (start >= token.start && end <= token.end) {
          segmentStyle = TextStyle(
            color: token.kind == AgentSyntaxKind.command
                ? colorScheme.primary
                : colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          );
          break;
        }
      }
      if (hasComposing && start >= composing.start && end <= composing.end) {
        segmentStyle = (segmentStyle ?? const TextStyle()).merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }

      children.add(
        TextSpan(text: text.substring(start, end), style: segmentStyle),
      );
    }

    return TextSpan(style: style, children: children);
  }
}
