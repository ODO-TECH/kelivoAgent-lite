import 'package:flutter/foundation.dart';

enum WorkspaceKind { managed, linked }

enum WorkspaceShellKind {
  automatic,
  powerShell,
  commandPrompt,
  gitBash,
  custom;

  static WorkspaceShellKind fromJson(Object? value) {
    return switch (value) {
      'powerShell' => WorkspaceShellKind.powerShell,
      'commandPrompt' => WorkspaceShellKind.commandPrompt,
      'gitBash' => WorkspaceShellKind.gitBash,
      'custom' => WorkspaceShellKind.custom,
      _ => WorkspaceShellKind.automatic,
    };
  }
}

class Workspace {
  final String id;
  final String name;
  final WorkspaceKind kind;
  final String? hostPath;
  final bool shellNeedsApproval;
  final WorkspaceShellKind shellKind;
  final String shellPath;
  final String defaultCwd;
  final Set<String> disabledTools;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.kind,
    this.hostPath,
    this.shellNeedsApproval = false,
    this.shellKind = WorkspaceShellKind.automatic,
    this.shellPath = '',
    this.defaultCwd = '',
    this.disabledTools = const {},
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  bool isToolEnabled(String name) => !disabledTools.contains(name);

  Workspace copyWith({
    String? id,
    String? name,
    WorkspaceKind? kind,
    String? hostPath,
    bool? shellNeedsApproval,
    WorkspaceShellKind? shellKind,
    String? shellPath,
    String? defaultCwd,
    Set<String>? disabledTools,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    bool clearHostPath = false,
    bool clearLastUsedAt = false,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      hostPath: clearHostPath ? null : (hostPath ?? this.hostPath),
      shellNeedsApproval: shellNeedsApproval ?? this.shellNeedsApproval,
      shellKind: shellKind ?? this.shellKind,
      shellPath: shellPath ?? this.shellPath,
      defaultCwd: defaultCwd ?? this.defaultCwd,
      disabledTools: disabledTools == null
          ? this.disabledTools
          : Set.unmodifiable(disabledTools),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'hostPath': hostPath,
    'shellNeedsApproval': shellNeedsApproval,
    'shellKind': shellKind.name,
    'shellPath': shellPath,
    'defaultCwd': defaultCwd,
    'disabledTools': disabledTools.toList()..sort(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
  };

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      kind: workspaceKindFromString(json['kind'] as String?),
      hostPath: json['hostPath'] as String?,
      shellNeedsApproval: json['shellNeedsApproval'] as bool? ?? false,
      shellKind: WorkspaceShellKind.fromJson(json['shellKind']),
      shellPath: (json['shellPath'] as String?) ?? '',
      defaultCwd: (json['defaultCwd'] as String?) ?? '',
      disabledTools: Set.unmodifiable(
        (json['disabledTools'] as List? ?? const []).cast<String>(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
    );
  }

  static WorkspaceKind workspaceKindFromString(String? value) {
    switch (value) {
      case 'linked':
        return WorkspaceKind.linked;
      case 'managed':
      default:
        return WorkspaceKind.managed;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Workspace &&
            other.id == id &&
            other.name == name &&
            other.kind == kind &&
            other.hostPath == hostPath &&
            other.shellNeedsApproval == shellNeedsApproval &&
            other.shellKind == shellKind &&
            other.shellPath == shellPath &&
            other.defaultCwd == defaultCwd &&
            setEquals(other.disabledTools, disabledTools) &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.lastUsedAt == lastUsedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    hostPath,
    shellNeedsApproval,
    shellKind,
    shellPath,
    defaultCwd,
    Object.hashAllUnordered(disabledTools),
    createdAt,
    updatedAt,
    lastUsedAt,
  );
}
