import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'flower_exception.dart';
import 'project_inspector.dart';
import 'project_map.dart';

/// Builds an analyzer-backed dependency map for one Dart or Flutter package.
final class ProjectMapper {
  const ProjectMapper({ProjectInspector? inspector})
    : _inspector = inspector ?? const ProjectInspector();

  final ProjectInspector _inspector;

  Future<ProjectMap> build(String rootPath) async {
    final snapshot = await _inspector.inspect(rootPath);
    final root = Directory(snapshot.rootPath);
    final libDirectory = Directory(p.join(root.path, 'lib'));

    if (!await libDirectory.exists()) {
      return ProjectMap(
        packageName: snapshot.packageName,
        rootPath: snapshot.rootPath,
        nodes: const <ProjectMapNode>[],
        edges: const <ProjectMapEdge>[],
        cycles: const <List<String>>[],
      );
    }

    final files = await _listDartFiles(libDirectory);
    final idsByAbsolutePath = <String, String>{};
    for (final file in files) {
      idsByAbsolutePath[p.normalize(p.absolute(file.path))] = _relativeId(
        root,
        file,
      );
    }

    final nodes = <ProjectMapNode>[];
    final edges = <ProjectMapEdge>[];

    for (final file in files) {
      final sourceId = idsByAbsolutePath[p.normalize(p.absolute(file.path))]!;
      final externalPackages = <String>{};
      final directives = await _readDirectives(file);

      for (final directive in directives) {
        final targetPath = _resolveTargetPath(
          root: root,
          source: file,
          packageName: snapshot.packageName,
          uriValue: directive.uri,
          externalPackages: externalPackages,
        );
        if (targetPath == null) {
          continue;
        }

        final targetId = idsByAbsolutePath[p.normalize(p.absolute(targetPath))];
        if (targetId == null) {
          continue;
        }

        edges.add(
          ProjectMapEdge(
            source: sourceId,
            target: targetId,
            kind: directive.kind,
          ),
        );
      }

      final sortedExternalPackages = externalPackages.toList()..sort();
      nodes.add(
        ProjectMapNode(
          id: sourceId,
          path: sourceId,
          feature: _featureForPath(sourceId),
          generated: _isGeneratedDartFile(sourceId),
          externalPackages: sortedExternalPackages,
        ),
      );
    }

    nodes.sort((left, right) => left.id.compareTo(right.id));
    edges.sort((left, right) {
      final sourceOrder = left.source.compareTo(right.source);
      if (sourceOrder != 0) {
        return sourceOrder;
      }
      final targetOrder = left.target.compareTo(right.target);
      if (targetOrder != 0) {
        return targetOrder;
      }
      return left.kind.index.compareTo(right.kind.index);
    });

    return ProjectMap(
      packageName: snapshot.packageName,
      rootPath: snapshot.rootPath,
      nodes: nodes,
      edges: edges,
      cycles: _findCycles(nodes, edges),
    );
  }

  Future<List<File>> _listDartFiles(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  Future<List<_ProjectDirective>> _readDirectives(File file) async {
    try {
      final result = parseString(
        content: await file.readAsString(),
        path: file.path,
        throwIfDiagnostics: false,
      );
      final directives = <_ProjectDirective>[];
      for (final directive in result.unit.directives) {
        final mapped = switch (directive) {
          ImportDirective() => _ProjectDirective(
            uri: directive.uri.stringValue,
            kind: ProjectMapEdgeKind.import,
          ),
          ExportDirective() => _ProjectDirective(
            uri: directive.uri.stringValue,
            kind: ProjectMapEdgeKind.export,
          ),
          PartDirective() => _ProjectDirective(
            uri: directive.uri.stringValue,
            kind: ProjectMapEdgeKind.part,
          ),
          _ => null,
        };
        if (mapped != null && mapped.uri != null) {
          directives.add(mapped);
        }
      }
      return directives;
    } on Object catch (error) {
      throw FlowerException(
        'Unable to analyze ${file.path}. Fix the file and retry.',
        cause: error,
      );
    }
  }

  String? _resolveTargetPath({
    required Directory root,
    required File source,
    required String packageName,
    required String? uriValue,
    required Set<String> externalPackages,
  }) {
    if (uriValue == null || uriValue.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(uriValue);
    if (uri == null) {
      return null;
    }

    if (uri.scheme == 'dart') {
      return null;
    }

    String targetPath;
    if (uri.scheme == 'package') {
      if (uri.pathSegments.isEmpty) {
        return null;
      }
      final importedPackage = uri.pathSegments.first;
      if (importedPackage != packageName) {
        externalPackages.add(importedPackage);
        return null;
      }
      targetPath = p.joinAll(<String>[
        root.path,
        'lib',
        ...uri.pathSegments.skip(1),
      ]);
    } else if (uri.scheme.isEmpty && !p.isAbsolute(uri.path)) {
      targetPath = p.normalize(p.join(p.dirname(source.path), uri.path));
    } else {
      return null;
    }

    final libPath = p.normalize(p.join(root.path, 'lib'));
    final normalizedTarget = p.normalize(p.absolute(targetPath));
    if (!p.isWithin(libPath, normalizedTarget) &&
        !p.equals(libPath, normalizedTarget)) {
      return null;
    }
    return normalizedTarget;
  }

  String _relativeId(Directory root, File file) {
    final relative = p.relative(file.path, from: root.path);
    return relative.split(p.separator).join('/');
  }

  String? _featureForPath(String path) {
    final segments = path.split('/');
    for (var index = 0; index < segments.length - 1; index++) {
      if (segments[index] == 'features' && index + 1 < segments.length) {
        return segments[index + 1];
      }
    }
    return null;
  }

  bool _isGeneratedDartFile(String path) {
    const suffixes = <String>[
      '.g.dart',
      '.freezed.dart',
      '.gr.dart',
      '.mocks.dart',
      '.config.dart',
    ];
    return suffixes.any(path.endsWith);
  }

  List<List<String>> _findCycles(
    List<ProjectMapNode> nodes,
    List<ProjectMapEdge> edges,
  ) {
    final adjacency = <String, List<String>>{
      for (final node in nodes) node.id: <String>[],
    };
    for (final edge in edges) {
      adjacency[edge.source]?.add(edge.target);
    }
    for (final targets in adjacency.values) {
      targets.sort();
    }

    var nextIndex = 0;
    final indexes = <String, int>{};
    final lowLinks = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final cycles = <List<String>>[];

    void strongConnect(String node) {
      indexes[node] = nextIndex;
      lowLinks[node] = nextIndex;
      nextIndex++;
      stack.add(node);
      onStack.add(node);

      for (final target in adjacency[node] ?? const <String>[]) {
        if (!indexes.containsKey(target)) {
          strongConnect(target);
          lowLinks[node] = _minimum(lowLinks[node]!, lowLinks[target]!);
        } else if (onStack.contains(target)) {
          lowLinks[node] = _minimum(lowLinks[node]!, indexes[target]!);
        }
      }

      if (lowLinks[node] != indexes[node]) {
        return;
      }

      final component = <String>[];
      while (stack.isNotEmpty) {
        final member = stack.removeLast();
        onStack.remove(member);
        component.add(member);
        if (member == node) {
          break;
        }
      }

      final hasSelfLoop =
          component.length == 1 &&
          (adjacency[component.single] ?? const <String>[]).contains(
            component.single,
          );
      if (component.length > 1 || hasSelfLoop) {
        component.sort();
        cycles.add(component);
      }
    }

    final sortedNodeIds = adjacency.keys.toList()..sort();
    for (final node in sortedNodeIds) {
      if (!indexes.containsKey(node)) {
        strongConnect(node);
      }
    }

    cycles.sort((left, right) => left.join('|').compareTo(right.join('|')));
    return cycles;
  }

  int _minimum(int left, int right) => left < right ? left : right;
}

final class _ProjectDirective {
  const _ProjectDirective({required this.uri, required this.kind});

  final String? uri;
  final ProjectMapEdgeKind kind;
}
