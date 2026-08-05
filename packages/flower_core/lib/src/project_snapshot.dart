import 'project_symbol_index.dart';

/// A deterministic snapshot of an inspected Dart or Flutter project.
final class ProjectSnapshot {
  ProjectSnapshot({
    required this.rootPath,
    required this.packageName,
    required this.description,
    required this.isFlutterProject,
    required this.sourceFileCount,
    required this.generatedFileCount,
    required this.testFileCount,
    required this.integrationTestFileCount,
    required Iterable<String> featureNames,
    required Map<String, List<String>> technologies,
    required Iterable<String> warnings,
    Map<String, int> symbolCounts = const <String, int>{},
    Iterable<ProjectRoute> routes = const <ProjectRoute>[],
  }) : featureNames = List.unmodifiable(featureNames),
       technologies = Map.unmodifiable(
         technologies.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       ),
       warnings = List.unmodifiable(warnings),
       symbolCounts = Map.unmodifiable(symbolCounts),
       routes = List.unmodifiable(routes);

  /// The current JSON contract version.
  static const int schemaVersion = 2;

  final String rootPath;
  final String packageName;
  final String description;
  final bool isFlutterProject;
  final int sourceFileCount;
  final int generatedFileCount;
  final int testFileCount;
  final int integrationTestFileCount;
  final List<String> featureNames;
  final Map<String, List<String>> technologies;
  final List<String> warnings;
  final Map<String, int> symbolCounts;
  final List<ProjectRoute> routes;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'rootPath': rootPath,
    'packageName': packageName,
    'description': description,
    'isFlutterProject': isFlutterProject,
    'files': <String, int>{
      'source': sourceFileCount,
      'generated': generatedFileCount,
      'test': testFileCount,
      'integrationTest': integrationTestFileCount,
    },
    'features': featureNames,
    'technologies': technologies,
    'architecture': <String, Object?>{
      'symbolCounts': symbolCounts,
      'routes': routes.map((route) => route.toJson()).toList(growable: false),
    },
    'warnings': warnings,
  };
}
