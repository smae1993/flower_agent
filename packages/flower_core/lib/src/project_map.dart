/// A stable, deterministic map of Dart files and their internal dependencies.
final class ProjectMap {
  const ProjectMap({
    required this.packageName,
    required this.rootPath,
    required this.nodes,
    required this.edges,
    required this.cycles,
  });

  static const String schemaVersion = '1.0.0';

  final String packageName;
  final String rootPath;
  final List<ProjectMapNode> nodes;
  final List<ProjectMapEdge> edges;
  final List<List<String>> cycles;

  Set<String> get features => <String>{
    for (final node in nodes)
      if (node.feature != null) node.feature!,
  };

  ProjectMap forFeature(String feature) {
    final selectedNodes = nodes
        .where((node) => node.feature == feature)
        .toList(growable: false);
    final selectedIds = selectedNodes.map((node) => node.id).toSet();
    final selectedEdges = edges
        .where(
          (edge) =>
              selectedIds.contains(edge.source) &&
              selectedIds.contains(edge.target),
        )
        .toList(growable: false);
    final selectedCycles = cycles
        .where((cycle) => cycle.every(selectedIds.contains))
        .toList(growable: false);

    return ProjectMap(
      packageName: packageName,
      rootPath: rootPath,
      nodes: selectedNodes,
      edges: selectedEdges,
      cycles: selectedCycles,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'packageName': packageName,
    'rootPath': rootPath,
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    'edges': edges.map((edge) => edge.toJson()).toList(growable: false),
    'cycles': cycles,
  };

  String toMermaid() {
    final buffer = StringBuffer('flowchart LR\n');
    final nodeIds = <String, String>{};

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final mermaidId = 'n$index';
      nodeIds[node.id] = mermaidId;
      final label = node.path.replaceAll('"', '\\"');
      buffer.writeln('  $mermaidId["$label"]');
    }

    for (final edge in edges) {
      final source = nodeIds[edge.source];
      final target = nodeIds[edge.target];
      if (source == null || target == null) {
        continue;
      }
      final arrow = switch (edge.kind) {
        ProjectMapEdgeKind.import => '-->',
        ProjectMapEdgeKind.export => '-.->',
        ProjectMapEdgeKind.part => '==>',
      };
      buffer.writeln('  $source $arrow $target');
    }

    final cycleNodeIds = cycles.expand((cycle) => cycle).toSet();
    final cycleMermaidIds = <String>[
      for (final id in cycleNodeIds)
        if (nodeIds[id] != null) nodeIds[id]!,
    ];
    if (cycleMermaidIds.isNotEmpty) {
      buffer
        ..writeln('  classDef cycle stroke-width:3px;')
        ..writeln('  class ${cycleMermaidIds.join(',')} cycle;');
    }

    return buffer.toString();
  }
}

final class ProjectMapNode {
  const ProjectMapNode({
    required this.id,
    required this.path,
    required this.feature,
    required this.generated,
    required this.externalPackages,
  });

  final String id;
  final String path;
  final String? feature;
  final bool generated;
  final List<String> externalPackages;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'path': path,
    'feature': feature,
    'generated': generated,
    'externalPackages': externalPackages,
  };
}

enum ProjectMapEdgeKind { import, export, part }

final class ProjectMapEdge {
  const ProjectMapEdge({
    required this.source,
    required this.target,
    required this.kind,
  });

  final String source;
  final String target;
  final ProjectMapEdgeKind kind;

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source,
    'target': target,
    'kind': kind.name,
  };
}
