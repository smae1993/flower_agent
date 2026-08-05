import 'project_symbol_index.dart';

/// A compact architecture symbol attached to a selected context file.
final class ContextSymbol {
  const ContextSymbol({required this.name, required this.kind});

  final String name;
  final ProjectSymbolKind kind;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'kind': kind.name,
  };
}

/// One project file selected as relevant to a requested task.
final class ContextFile {
  ContextFile({
    required this.path,
    required this.feature,
    required this.score,
    required Iterable<String> reasons,
    required Iterable<ContextSymbol> symbols,
    required Iterable<String> dependencies,
    required Iterable<String> dependents,
  }) : reasons = List.unmodifiable(reasons),
       symbols = List.unmodifiable(symbols),
       dependencies = List.unmodifiable(dependencies),
       dependents = List.unmodifiable(dependents);

  final String path;
  final String? feature;
  final int score;
  final List<String> reasons;
  final List<ContextSymbol> symbols;
  final List<String> dependencies;
  final List<String> dependents;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'feature': feature,
    'score': score,
    'reasons': reasons,
    'symbols': symbols.map((symbol) => symbol.toJson()).toList(growable: false),
    'dependencies': dependencies,
    'dependents': dependents,
  };
}

/// Deterministic task-specific project context for a coding agent.
final class ProjectContext {
  ProjectContext({
    required this.task,
    required this.packageName,
    required this.rootPath,
    required this.limit,
    required Iterable<String> queryTerms,
    required Iterable<String> matchedFeatures,
    required Iterable<ContextFile> files,
    required Iterable<ProjectRoute> routes,
    required Iterable<String> warnings,
  }) : queryTerms = List.unmodifiable(queryTerms),
       matchedFeatures = List.unmodifiable(matchedFeatures),
       files = List.unmodifiable(files),
       routes = List.unmodifiable(routes),
       warnings = List.unmodifiable(warnings);

  static const String schemaVersion = '1.0.0';

  final String task;
  final String packageName;
  final String rootPath;
  final int limit;
  final List<String> queryTerms;
  final List<String> matchedFeatures;
  final List<ContextFile> files;
  final List<ProjectRoute> routes;
  final List<String> warnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'task': task,
    'packageName': packageName,
    'rootPath': rootPath,
    'limit': limit,
    'queryTerms': queryTerms,
    'matchedFeatures': matchedFeatures,
    'files': files.map((file) => file.toJson()).toList(growable: false),
    'routes': routes.map((route) => route.toJson()).toList(growable: false),
    'warnings': warnings,
  };

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Flower Task Context')
      ..writeln()
      ..writeln('**Task:** $task')
      ..writeln()
      ..writeln('**Project:** `$packageName`')
      ..writeln()
      ..writeln('**Selected files:** `${files.length}` of limit `$limit`')
      ..writeln();

    if (queryTerms.isNotEmpty) {
      buffer
        ..writeln(
          '**Query terms:** ${queryTerms.map((term) => '`$term`').join(', ')}',
        )
        ..writeln();
    }

    if (matchedFeatures.isNotEmpty) {
      buffer
        ..writeln(
          '**Matched features:** '
          '${matchedFeatures.map((feature) => '`$feature`').join(', ')}',
        )
        ..writeln();
    }

    buffer.writeln('## Relevant files');
    buffer.writeln();
    if (files.isEmpty) {
      buffer.writeln('No project files were selected.');
    } else {
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        buffer.writeln('${index + 1}. `${file.path}` — score `${file.score}`');
        if (file.feature != null) {
          buffer.writeln('   - Feature: `${file.feature}`');
        }
        for (final reason in file.reasons) {
          buffer.writeln('   - $reason');
        }
        if (file.symbols.isNotEmpty) {
          final summary = file.symbols
              .map((symbol) => '${symbol.kind.name}:${symbol.name}')
              .join(', ');
          buffer.writeln('   - Symbols: `$summary`');
        }
        if (file.dependencies.isNotEmpty) {
          buffer.writeln(
            '   - Direct dependencies: '
            '${file.dependencies.map((path) => '`$path`').join(', ')}',
          );
        }
        if (file.dependents.isNotEmpty) {
          buffer.writeln(
            '   - Direct dependents: '
            '${file.dependents.map((path) => '`$path`').join(', ')}',
          );
        }
      }
    }

    if (routes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Relevant routes')
        ..writeln();
      for (final route in routes) {
        final label =
            route.name ?? route.path ?? route.declaration ?? '<unnamed>';
        buffer.writeln(
          '- `$label` via `${route.router}` '
          'in `${route.sourcePath}:${route.line}`',
        );
      }
    }

    if (warnings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Warnings')
        ..writeln();
      for (final warning in warnings) {
        buffer.writeln('- $warning');
      }
    }

    return buffer.toString();
  }
}
