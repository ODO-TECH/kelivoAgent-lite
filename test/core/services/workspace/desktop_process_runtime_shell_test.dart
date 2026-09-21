import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

void main() {
  test('runs a command through the selected Windows command prompt', () async {
    final runtime = DesktopProcessRuntime();
    final output = StringBuffer();
    final events = runtime.run(
      const CommandRequest(
        runId: 'shell-test',
        command: 'echo kelivo-shell-ok',
        cwd: '.',
        shellKind: 'commandPrompt',
      ),
    );
    late CommandExited exit;
    await for (final event in events) {
      if (event is CommandOutput) {
        output.write(utf8.decode(event.bytes, allowMalformed: true));
      }
      if (event is CommandExited) exit = event;
    }
    expect(exit.exitCode, 0);
    expect(output.toString(), contains('kelivo-shell-ok'));
  }, skip: !Platform.isWindows);
}
