import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'project_inspector.dart';
import 'project_snapshot.dart';

/// The result of safely initializing Flower in a project.
final class InitializationResult {
  InitializationResult({
    required this.snapshot,
    required Iterable<String> createdFiles,
    required Iterable<String> skippedFiles,
  }) : createdFiles = List.unmodifiable(createdFiles),
       skippedFiles = List.unmodifiable(skippedFiles);

  final ProjectSnapshot snapshot;
  final List<String> createdFiles;
  final List<String> skippedFiles;
}

/// Creates Flower's project-local files without replacing existing content.
final class ProjectInitializer {
  const ProjectInitializer({this.inspector = const ProjectInspector()});

  final ProjectInspector inspector;

  Future<InitializationResult> initialize(String rootPath) async {
    final snapshot = await inspector.inspect(rootPath);
    final createdFiles = <String>[];
    final skippedFiles = <String>[];

    await _createOnly(
      rootPath: snapshot.rootPath,
      relativePath: p.join('.flower', 'flower.yaml'),
      content: _buildConfiguration(snapshot),
      createdFiles: createdFiles,
      skippedFiles: skippedFiles,
    );
    await _createOnly(
      rootPath: snapshot.rootPath,
      relativePath: p.join('.flower', 'context', 'project.md'),
      content: _buildProjectContext(snapshot),
      createdFiles: createdFiles,
      skippedFiles: skippedFiles,
    );
    await _createOnly(
      rootPath: snapshot.rootPath,
      relativePath: 'AGENTS.md',
      content: _buildAgentInstructions(),
      createdFiles: createdFiles,
      skippedFiles: skippedFiles,
    );

    return InitializationResult(
      snapshot: snapshot,
      createdFiles: createdFiles,
      skippedFiles: skippedFiles,
    );
  }

  Future<void> _createOnly({
    required String rootPath,
    required String relativePath,
    required String content,
    required List<String> createdFiles,
    required List<String> skippedFiles,
  }) async {
    final file = File(p.join(rootPath, relativePath));
    if (await file.exists()) {
      skippedFiles.add(relativePath);
      return;
    }

    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    createdFiles.add(relativePath);
  }

  String _buildConfiguration(ProjectSnapshot snapshot) {
    final buffer = StringBuffer()
      ..writeln('schema_version: ${ProjectSnapshot.schemaVersion}')
      ..writeln('project:')
      ..writeln('  name: ${jsonEncode(snapshot.packageName)}')
      ..writeln('  root: "."')
      ..writeln('  flutter: ${snapshot.isFlutterProject}')
      ..writeln('architecture:')
      ..writeln(
        '  style: ${snapshot.featureNames.isEmpty ? 'unclassified' : 'feature_first'}',
      )
      ..writeln('  detected:');

    for (final entry in snapshot.symbolCounts.entries) {
      buffer.writeln('    ${entry.key}: ${entry.value}');
    }
    buffer
      ..writeln('    routes: ${snapshot.routes.length}')
      ..writeln('technologies:');

    if (snapshot.technologies.isEmpty) {
      buffer.writeln('  {}');
    } else {
      for (final entry in snapshot.technologies.entries) {
        buffer.writeln('  ${entry.key}:');
        for (final packageName in entry.value) {
          buffer.writeln('    - ${jsonEncode(packageName)}');
        }
      }
    }

    buffer
      ..writeln('guard:')
      ..writeln('  enabled: true')
      ..writeln('  fail_on: error');
    return buffer.toString();
  }

  String _buildProjectContext(ProjectSnapshot snapshot) {
    final buffer = StringBuffer()
      ..writeln('# Flower Project Context')
      ..writeln()
      ..writeln('This file was generated during `flower init`.')
      ..writeln()
      ..writeln('## Project')
      ..writeln()
      ..writeln('- Package: `${snapshot.packageName}`')
      ..writeln('- Flutter project: `${snapshot.isFlutterProject}`')
      ..writeln('- Source files: `${snapshot.sourceFileCount}`')
      ..writeln('- Generated files: `${snapshot.generatedFileCount}`')
      ..writeln('- Unit test files: `${snapshot.testFileCount}`')
      ..writeln(
        '- Integration test files: `${snapshot.integrationTestFileCount}`',
      )
      ..writeln()
      ..writeln('## Detected technologies')
      ..writeln();

    if (snapshot.technologies.isEmpty) {
      buffer.writeln('No supported technology packages were detected.');
    } else {
      for (final entry in snapshot.technologies.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value.join(', ')}');
      }
    }

    buffer
      ..writeln()
      ..writeln('## Architecture symbols')
      ..writeln();
    for (final entry in snapshot.symbolCounts.entries) {
      buffer.writeln('- ${entry.key}: `${entry.value}`');
    }
    buffer.writeln('- routes: `${snapshot.routes.length}`');

    if (snapshot.routes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Routes')
        ..writeln();
      for (final route in snapshot.routes) {
        final label = route.name ?? route.path ?? route.declaration ?? '<unnamed>';
        buffer.writeln(
          '- `$label` via `${route.router}` in `${route.sourcePath}:${route.line}`',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('## Features')
      ..writeln();
    if (snapshot.featureNames.isEmpty) {
      buffer.writeln('No feature-first directories were detected.');
    } else {
      for (final feature in snapshot.featureNames) {
        buffer.writeln('- `$feature`');
      }
    }

    buffer
      ..writeln()
      ..writeln('## Next steps')
      ..writeln()
      ..writeln('1. Review `.flower/flower.yaml`.')
      ..writeln('2. Run `flower symbols --json` for declaration-level context.')
      ..writeln('3. Add project-specific architecture rules and decisions.')
      ..writeln('4. Run `flower inspect` after major structural changes.');
    return buffer.toString();
  }

  String _buildAgentInstructions() => '''
# Project Instructions for Coding Agents

This project uses Flower Agent for project intelligence and architecture governance.

Before changing code:

1. Read `.flower/context/project.md`.
2. Respect `.flower/flower.yaml` and project-local architecture decisions.
3. Use `flower symbols --json` when declaration-level context is needed.
4. Inspect the project when the stored context may be stale.
5. Keep changes inside the appropriate feature and layer.
6. Run formatting, analysis, and relevant tests before completion.

Do not overwrite project configuration or generated context without explaining the change.
''';
}
