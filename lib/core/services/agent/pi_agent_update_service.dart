import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';

class PiAgentUpdateInfo {
  const PiAgentUpdateInfo({required this.current, required this.latest});

  final String current;
  final String latest;

  bool get available => _compareVersions(latest, current) > 0;
}

/// Checks the npm release channel used by the embedded pi coding agent.
/// Updates are staged under app data so a failed download never replaces the
/// running sidecar. A packaged sidecar can consume the staged version after a
/// future rebuild; source/bun installations can apply it immediately.
class PiAgentUpdateService {
  const PiAgentUpdateService({this.client, this.currentVersion = '0.73.1'});

  final http.Client? client;
  final String currentVersion;

  Future<PiAgentUpdateInfo> checkLatest() async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(
            Uri.parse(
              'https://registry.npmjs.org/@mariozechner/pi-coding-agent/latest',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'pi Agent version check failed (${response.statusCode})',
        );
      }
      final decoded = jsonDecode(response.body);
      final latest = decoded is Map
          ? decoded['version']?.toString().trim()
          : null;
      if (latest == null || latest.isEmpty)
        throw const FormatException('Missing pi version');
      return PiAgentUpdateInfo(current: currentVersion, latest: latest);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<File> stageLatest(PiAgentUpdateInfo info) async {
    if (!info.available)
      throw StateError('No newer pi Agent version is available');
    final httpClient = client ?? http.Client();
    try {
      final metadataResponse = await httpClient
          .get(
            Uri.parse(
              'https://registry.npmjs.org/@mariozechner/pi-coding-agent/${Uri.encodeComponent(info.latest)}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (metadataResponse.statusCode < 200 ||
          metadataResponse.statusCode >= 300) {
        throw HttpException(
          'pi Agent package metadata failed (${metadataResponse.statusCode})',
        );
      }
      final metadata = jsonDecode(metadataResponse.body);
      String? tarball;
      if (metadata is Map) {
        final dist = metadata['dist'];
        if (dist is Map) {
          tarball = dist['tarball']?.toString();
        }
      }
      if (tarball == null || tarball.isEmpty)
        throw const FormatException('Missing pi tarball');
      final response = await httpClient
          .get(Uri.parse(tarball))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'pi Agent package download failed (${response.statusCode})',
        );
      }
      final root = await AppDirectories.getAppDataDirectory();
      final dir = Directory(p.join(root.path, 'pi-agent-updates'));
      await dir.create(recursive: true);
      final target = File(
        p.join(dir.path, 'pi-coding-agent-${info.latest}.tgz'),
      );
      await target.writeAsBytes(response.bodyBytes, flush: true);
      return target;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

int _compareVersions(String left, String right) {
  List<int> parse(String value) => value
      .replaceFirst(RegExp(r'^[^0-9]*'), '')
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .take(3)
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final a = parse(left), b = parse(right);
  for (var i = 0; i < 3; i++) {
    final diff = (a.length > i ? a[i] : 0) - (b.length > i ? b[i] : 0);
    if (diff != 0) return diff.sign;
  }
  return 0;
}
